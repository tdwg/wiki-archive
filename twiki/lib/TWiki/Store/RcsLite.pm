# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Store::RcsLite

This package does not publish any methods. It implements the virtual
methods of the [[TWikiStoreRcsFileDotPm][TWiki::Store::RcsFile]] superclass.

Simple replacement for RCS.  Doesn't support:
   * branches
   * locking
Neither of which are used (or needed) by TWiki.

This module doesn't know anything about the content of the topic

There is one of these object for each file stored under RCSLite.

This object is PACKAGE PRIVATE to Store, and should NEVER be
used from anywhere else.

FIXME:
   * need to tidy up dealing with \n for differences
   * still have difficulty on line ending at end of sequences, consequence of doing a line based diff

---++ File format

<verbatim>
rcstext    ::=  admin {delta}* desc {deltatext}*
admin      ::=  head {num};
                { branch   {num}; }
                access {id}*;
                symbols {sym : num}*;
                locks {id : num}*;  {strict  ;}
                { comment  {string}; }
                { expand   {string}; }
                { newphrase }*
delta      ::=  num
                date num;
                author id;
                state {id};
                branches {num}*;
                next {num};
                { newphrase }*
desc       ::=  desc string
deltatext  ::=  num
                log string
                { newphrase }*
                text string
num        ::=  {digit | .}+
digit      ::=  0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
id         ::=  {num} idchar {idchar | num }*
sym        ::=  {digit}* idchar {idchar | digit }*
idchar     ::=  any visible graphic character except special
special    ::=  $ | , | . | : | ; | @
string     ::=  @{any character, with @ doubled}*@
newphrase  ::=  id word* ;
word       ::=  id | num | string | :
</verbatim>
Identifiers are case sensitive. Keywords are in lower case only. The
sets of keywords and identifiers can overlap. In most environments RCS
uses the ISO 8859/1 encoding: visible graphic characters are codes
041-176 and 240-377, and white space characters are codes 010-015 and 040.

Dates, which appear after the date keyword, are of the form Y.mm.dd.hh.mm.ss,
where Y is the year, mm the month (01-12), dd the day (01-31), hh the hour
(00-23), mm the minute (00-59), and ss the second (00-60). Y contains just
the last two digits of the year for years from 1900 through 1999, and all
the digits of years thereafter. Dates use the Gregorian calendar; times
use UTC.

The newphrase productions in the grammar are reserved for future extensions
to the format of RCS files. No newphrase will begin with any keyword already
in use.

Revisions consist of a sequence of 'a' and 'd' edits that need to be
applied to rev N+1 to get rev N. Each edit has an offset (number of lines
from start) and length (number of lines). For 'a', the edit is followed by
length lines (the lines to be inserted in the text). For example:

d1 3     means "delete three lines starting with line 1
a4 2     means "insert two lines at line 4'
xxxxxx   is the new line 4
yyyyyy   is the new line 5

=cut

package TWiki::Store::RcsLite;

use TWiki::Store::RcsFile;
@ISA = qw(TWiki::Store::RcsFile);

use strict;
#use Algorithm::Diff;# qw(diff sdiff);
use Algorithm::Diff;
use FileHandle;
use Assert;
use TWiki::Time;
use Error qw( :try );

my $N = "\n";
my $T = "\t";

#
# As well as the field inherited from RcsFile, the object for each file
# read consists of the following fields:
# head    - version number of head
# access  - the access field from the file
# symbols - the symbols field from the file
# comment - the comment field from the file
# desc    - the desc field from the file
# expand  - 'b' for binary, or null
# author  - ref to array of version authors
# date    - ref to array of dates indexed by version number
# log     - ref to array of messages indexed by version
# delta   - ref to array of deltas indexed by version
# where   - 'nofile' if there is no ,v file, or a text string
#           representing the parse state when the parse finished.
#           If the parse was successful this will be 'parsed'.
#

# implements RcsFile
sub new {
    my( $class, $session, $web, $topic, $attachment, $settings ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this =
      bless( new TWiki::Store::RcsFile( $session, $web, $topic,
                                        $attachment, $settings ),
             $class );
    $this->{head} = 0;
    $this->{access} = '';
    $this->{symbols} = '';
    $this->{comment} = '';
    $this->{desc} = '';
    return $this;
}

=pod

---++ ObjectMethod finish

Complete processing after the client's HTTP request has been responded
to.
   1 breaking circular references to allow garbage collection in persistent
     environments

=cut

sub finish {
    my $this = shift;

}

sub _readTo {
    my( $file, $char ) = @_;
    my $buf = '';
    my $ch;
    my $space = 0;
    my $string = '';
    my $state = '';
    while( read( $file, $ch, 1 ) ) {
        if( $ch eq '@' ) {
            if( $state eq '@' ) {
                $state = 'e';
                next;
            } elsif( $state eq 'e' ) {
                $state = '@';
                $string .= '@';
                next;
            } else {
                $state = '@';
                next;
            }
        } else {
            if( $state eq 'e' ) {
                $state = '';
                if( $char eq '@' ) {
                    last;
                }
                # End of string
            } elsif ( $state eq '@' ) {
                $string .= $ch;
                next;
            }
        }
        if( $ch =~ /\s/ ) {
            if( length( $buf ) == 0 ) {
                next;
            } elsif( $space ) {
                next;
            } else {
                $space = 1;
                $ch = ' ';
            }
        } else {
            $space = 0;
        }
        $buf .= $ch;
        if( $ch eq $char ) {
            last;
        }
    }
    return( $buf, $string );
}

# Make sure RCS file has been read in and there is history
sub _ensureProcessed {
    my( $this ) = @_;
    if( ! $this->{state} ) {
        $this->_process();
    }
}

# Read in the whole RCS file (assuming it exists)
sub _process {
    my( $this ) = @_;
    my $rcsFile = TWiki::Sandbox::normalizeFileName( $this->{rcsFile} );
    if( ! -e $rcsFile ) {
        $this->{state} = 'nocommav';
        return;
    }
    my $fh = new FileHandle;
    if( ! $fh->open( $rcsFile ) ) {
        $this->{session}->writeWarning( 'Failed to open '.$rcsFile );
        $this->{state} = 'nocommav';
        return;
    }
    binmode( $fh );
    my $state = 'admin.head';
    my $term = ';';
    my $string = '';
    my $num = '';
    my $headNum = 0;
    my @revs = ();
    my $dnum = '';
    while( 1 ) {
        ($_, $string) = _readTo( $fh, $term );
        last if( ! $_ );

        if( $state eq 'admin.head' ) {
            if( /^head\s+([0-9]+)\.([0-9]+);$/o ) {
                ASSERT( $1 eq 1 ) if DEBUG;
                $headNum = $2;
                $state = 'admin.access'; # Don't support branches
            } else {
                last;
            }
        } elsif( $state eq 'admin.access' ) {
            if( /^access\s*(.*);$/o ) {
                $state = 'admin.symbols';
                $this->{access} = $1;
            } else {
                last;
            }
        } elsif( $state eq 'admin.symbols' ) {
            if( /^symbols(.*);$/o ) {
                $state = 'admin.locks';
                $this->{symbols} = $1;
            } else {
                last;
            }
        } elsif( $state eq 'admin.locks' ) {
            if( /^locks.*;$/o ) {
                $state = 'admin.postLocks';
            } else {
                last;
            }
        } elsif( $state eq 'admin.postLocks' ) {
            if( /^strict\s*;/o ) {
                $state = 'admin.postStrict';
            }
        } elsif( $state eq 'admin.postStrict' &&
                 /^comment\s.*$/o ) {
            $state = 'admin.postComment';
            $this->{comment} = $string;
        } elsif( ( $state eq 'admin.postStrict' ||
                   $state eq 'admin.postComment' )  &&
                 /^expand\s/o ) {
            $state = 'admin.postExpand';
            $this->{expand} = $string;
        } elsif( $state eq 'admin.postStrict' ||
                 $state eq 'admin.postComment' ||
                 $state eq 'admin.postExpand' ||
                 $state eq 'delta.date') {
            if( /^([0-9]+)\.([0-9]+)\s+date\s+(\d\d(\d\d)?(\.\d\d){5}?);$/o ) {
                $state = 'delta.author';
                $num = $2;
                $revs[$num]->{date} = TWiki::Time::parseTime($3);
            }
        } elsif( $state eq 'delta.author' ) {
            if( /^author\s+(.*);$/o ) {
                $revs[$num]->{author} = $1;
                if( $num == 1 ) {
                    $state = 'desc';
                    $term = '@';
                } else {
                    $state = 'delta.date';
                }
            }
        } elsif( $state eq 'desc' ) {
            if( /desc\s*$/o ) {
                $this->{desc} = $string;
                $state = 'deltatext.log';
            }
        } elsif( $state eq 'deltatext.log' ) {
            if( /\d+\.(\d+)\s+log\s+$/o ) {
                $dnum = $1;
                $revs[$dnum]->{log} = $string;
                $state = 'deltatext.text';
            }
        } elsif( $state eq 'deltatext.text' ) {
            if( /text\s*$/o ) {
                $state = 'deltatext.log';
                $revs[$dnum]->{text} = $string;
                if( $dnum == 1 ) {
                    $state = 'parsed';
                    last;
                }
            }
        }
    }

    unless( $state eq 'parsed' ) {
        my $error = $this->{rcsFile}.' is corrupt; parsed up to '.$state;
        $this->{session}->writeWarning( $error );
        #ASSERT(0) if DEBUG;
        $headNum = 0;
        $state = 'nocommav'; # ignore the RCS file; graceful recovery
    }

    $this->{head} = $headNum;
    $this->{state} = $state;
    $this->{revs} = \@revs;

    close( $fh );
}

sub _formatString {
    my( $str ) = @_;
    $str ||= '';
    $str =~ s/@/@@/go;
    return '@'.$str.'@';
}

# Write content of the RCS file
sub _write {
    my( $this, $file ) = @_;

    # admin
    my $nr = $this->{head} || 1;
    print $file <<HERE;
head	1.$nr;
access	$this->{access};
symbols$this->{symbols};
locks; strict;
HERE
    print $file 'comment',$T,_formatString( $this->{comment} ),';',$N;
    if( $this->{expand} ) {
        print $file 'expand',$T,_formatString( $this->{expand} ),';'.$N;
    }

    print $file $N;

    # most recent rev first
    for( my $i = $this->{head}; $i > 0; $i--) {
        my $d = $this->{revs}[$i]->{date};
        my $rcsDate = TWiki::Store::RcsFile::_epochToRcsDateTime( $d );
        print $file <<HERE;
1.$i
date	$rcsDate;	author $this->{revs}[$i]->{author};	state Exp;
branches;	
HERE
        print $file 'next',$T;
        print $file '1.',($i - 1) if( $i > 1 );
        print $file ';'.$N;
    }

    print $file $N,$N,'desc',$N, _formatString( $this->{desc} ).$N,$N;

    for( my $i = $this->{head}; $i > 0; $i--) {
        print $file $N,'1.',$i,$N,
          'log',$N,_formatString( $this->{revs}[$i]->{log} ),
            $N,'text',$N,_formatString( $this->{revs}[$i]->{text} ),$N,$N;
    }
    $this->{state} = 'parsed'; # now known clean
}

# implements RcsFile
sub initBinary {
    my( $this ) = @_;
    # Nothing to be done but note for re-writing
    $this->{expand} = 'b';
}

# implements RcsFile
sub initText {
    my( $this ) = @_;
    # Nothing to be done but note for re-writing
    $this->{expand} = '';
}

# implements RcsFile
sub numRevisions {
    my( $this ) = @_;
    $this->_ensureProcessed();
    # if state is nocommav, and the file exists, there is only one revision
    if( $this->{state} eq 'nocommav' ) {
        return 1 if( -e $this->{file} );
        return 0;
    }
    return $this->{head};
}

# implements RcsFile
sub addRevisionFromText {
    shift->_addRevision( 0, @_ );
}

sub addRevisionFromStream {
    shift->_addRevision( 1, @_ );
}

sub _addRevision {
    my( $this, $isStream, $data, $log, $author, $date ) = @_;

    $this->_ensureProcessed();

    if( $this->{state} eq 'nocommav' && -e $this->{file} ) {
        # Must do this *before* saving the attachment, so we
        # save the file on disc
        $this->{head} = 1;
        $this->{revs}[1]->{text} = $this->_readFile( $this->{file} );
        $this->{revs}[1]->{log} = $log;
        $this->{revs}[1]->{author} = $author;
        $this->{revs}[1]->{date} = (defined $date ? $date : time());
        $this->_writeMe();
    }

    if( $isStream ) {
        $this->_saveStream( $data );
        # SMELL: for big attachments, this is a dog
        $data = $this->_readFile( $this->{file} );
    } else {
        $this->_saveFile( $this->{file}, $data );
    }

    my $head = $this->{head};
    if( $head ) {
        my $lNew = _split( $data );
        my $lOld = _split( $this->{revs}[$head]->{text} );
        my $delta = _diff( $lNew, $lOld );
        $this->{revs}[$head]->{text} = $delta;
    }
    $head++;
    $this->{revs}[$head]->{text} = $data;
    $this->{head} = $head;
    $this->{revs}[$head]->{log} = $log;
    $this->{revs}[$head]->{author} = $author;
    $this->{revs}[$head]->{date} = ( defined $date ? $date : time());

    return $this->_writeMe();
}

sub _writeMe {
    my( $this ) = @_;
    my $dataError = '';
    my $out = new FileHandle();

    chmod( $TWiki::cfg{RCS}{filePermission}, $this->{rcsFile} );
    if( !$out->open( '>'.TWiki::Sandbox::normalizeFileName( $this->{rcsFile} ))) {
        throw Error::Simple('Cannot open '.$this->{rcsFile}.
                            ' for write: '.$! );
    } else {
        binmode( $out );
        $this->_write( $out );
        close( $out );
    }
    chmod( $TWiki::cfg{RCS}{filePermission}, $this->{rcsFile} );

    return $dataError;
}

# implements RcsFile
sub replaceRevision {
    my( $this, $text, $comment, $user, $date ) = @_;
    $this->_ensureProcessed();
    $this->_delLastRevision();
    return $this->_addRevision( 0, $text, $comment, $user, $date );
}

# implements RcsFile
sub deleteRevision {
    my( $this ) = @_;
    $this->_ensureProcessed();
    # Can't delete revision 1
    return unless $this->{head} > 1;
    $this->_delLastRevision();
    return $this->_writeMe();
}

sub _delLastRevision {
    my( $this ) = @_;
    my $numRevisions = $this->{head};
    return unless $numRevisions;
    $numRevisions--;
    my $lastText = $this->getRevision( $numRevisions );
    $this->{revs}[$numRevisions]->{text} = $lastText;
    $this->{head} = $numRevisions;
    $this->_saveFile( $this->{file}, $lastText );
}

# implements RcsFile
# Recovers the two revisions and uses sdiff on them. Simplest way to do
# this operation.
sub revisionDiff {
    my( $this, $rev1, $rev2, $contextLines ) = @_;
    my @list;
    $this->_ensureProcessed();
    my $text1 = $this->getRevision( $rev1 );
    my $text2 = $this->getRevision( $rev2 );
	
    my $lNew = _split( $text1 );
    my $lOld = _split( $text2 );
    my $diff = Algorithm::Diff::sdiff( $lNew, $lOld );

    foreach my $ele ( @$diff ) {
        push @list, $ele;
    }
	return \@list;	
}

# implements RcsFile
sub getRevisionInfo {
    my( $this, $version ) = @_;

    $this->_ensureProcessed();

    if( $this->{state} ne 'nocommav' ) {
        if( !$version || $version > $this->{head} ) {
            $version = $this->{head} || 1;
        }
        return ( $version,
                 $this->{revs}[$version]->{date},
                 $this->{revs}[$version]->{author},
                 $this->{revs}[$version]->{log} );
    }
    return $this->SUPER::getRevisionInfo( $version );
}

# Apply delta (patch) to text.  Note that RCS stores reverse deltas,
# so the text for revision x is patched to produce text for revision x-1.
sub _patch {
    # Both params are references to arrays
    my( $text, $delta ) = @_;
    my $adj = 0;
    my $pos = 0;
    my $max = $#$delta;
    while( $pos <= $max ) {
        my $d = $delta->[$pos];
        if( $d =~ /^([ad])(\d+)\s(\d+)$/ ) {
            my $act = $1;
            my $offset = $2;
            my $length = $3;
            if( $act eq 'd' ) {
                my $start = $offset + $adj - 1;
                my @removed = splice( @$text, $start, $length );
                $adj -= $length;
                $pos++;
            } elsif( $act eq 'a' ) {
                my @toAdd = @$delta[$pos+1..$pos+$length];
                # Fix for Item2957
                # Check if the last element of what is to be added contains
                # a valid marker. If it does, the chances are very high that
                # this topic was saved using a broken version of RcsLite, and
                # a line ending has been lost.
                # As soon as a topic containing this problem is re-saved
                # using this code, the need for this hack should go away,
                # as the line endings will now be correct.
                if (scalar(@toAdd) &&
                      $toAdd[$#toAdd] =~ /^([ad])(\d+)\s(\d+)$/ &&
                        $2 > $pos) {
                    pop(@toAdd);
                    push(@toAdd, <<'HERE');
<div class="twikiAlert">WARNING: THIS TEXT WAS ADDED BY THE SYSTEM TO CORRECT A PROBABLE ERROR IN THE HISTORY OF THIS TOPIC.</div>
HERE
                    $pos--; # so when we add $length we get to the right place
                }
                splice( @$text, $offset + $adj, 0, @toAdd );

                $adj += $length;
                $pos += $length + 1;
            }
        } else {
            last;
        }
    }
}

# implements RcsFile
sub getRevision {
    my( $this, $version ) = @_;

    return $this->SUPER::getRevision($version) unless $version;

    $this->_ensureProcessed();

    return $this->SUPER::getRevision($version) if $this->{state} eq 'nocommav';

    my $head = $this->{head};
    $this->SUPER::getRevision($version) unless $head;
    if( $version == $head ) {
        return $this->{revs}[$version]->{text};
    }
    $version = $head if $version > $head;
    my $headText = $this->{revs}[$head]->{text};
    my $text = _split( $headText );
    return $this->_patchN( $text, $head-1, $version );
}

# Apply reverse diffs until we reach our target rev
sub _patchN {
    my( $this, $text, $version, $target ) = @_;

    while ($version >= $target) {
        my $deltaText = $this->{revs}[$version--]->{text};
        my $delta = _split( $deltaText );
        _patch( $text, $delta );
    }
    return join( "\n", @$text );
}


# Split a string on \n making sure we have all newlines. If the string
# ends with \n there will be a '' at the end of the split.
sub _split {
    #my $text = shift;

    my @list = ();
    return \@list unless defined $_[0];

    my $nl = 1;
    foreach my $i ( split( /(\n)/o, $_[0] ) ) {
        if( $i eq "\n" ) {
            push( @list, '' ) if $nl;
            $nl = 1;
        } else {
            push( @list, $i );
            $nl = 0;
        }
    }
    push( @list, '' ) if ($nl);

    return \@list;
}

# Extract the differences between two arrays of lines, returning a string
# of differences in RCS difference format.
sub _diff {
    my( $new, $old ) = @_;
    my $diffs = Algorithm::Diff::diff( $new, $old );
	#print STDERR "DIFF '",join('\n',@$new),"' and '",join('\n',@$old),"'\n";
    # Convert the differences to RCS format
    my $adj = 0;
    my $out = '';
    my $start = 0;
    foreach my $chunk ( @$diffs ) {
        my $count++;
        my $chunkSign;
        my @lines = ();
        foreach my $line ( @$chunk ) {
            my( $sign, $pos, $what ) = @$line;
            #print STDERR "....$sign $pos $what\n";
            if( $chunkSign && $chunkSign ne $sign ) {
                $adj += _addChunk( $chunkSign, \$out, \@lines, $start, $adj );
            }
            if( ! @lines ) {
                $start = $pos;
            }
            $chunkSign = $sign;
            push( @lines, $what );
        }

        $adj += _addChunk( $chunkSign, \$out, \@lines, $start, $adj );
    }
    $out .= $N;
    #print STDERR "CONVERTED\n",$out,"\n";
    return $out;
}

# Add a hunk of differences, returning the total number of lines in the
# text
sub _addChunk {
    my( $chunkSign, $out, $lines, $start, $adj ) = @_;

    my $nLines = scalar( @$lines );
    if( $nLines > 0 ) {
        $$out .= $N if( $$out && $$out !~ /\n$/o );
        if( $chunkSign eq '+' ) {
            # Added $N at end to correct Item2957
            $$out .= 'a'.($start-$adj).' '.$nLines.$N.join( "\n", @$lines ).$N;
        } else {
            $$out .= 'd'.($start+1).' '.$nLines;
            $nLines *= -1;
        }
        @$lines = ();
    }
    return $nLines;
}

sub getRevisionAtTime {
    my( $this, $date ) = @_;

    my $version = 1;

    $this->_ensureProcessed();

    $version = $this->{head};

    while( $version > 1 && $this->{revs}[$version]->{date} > $date) {
        $version--;
    }

    return $version;
}

sub stringify {
    my $this = shift;

    my $s = $this->SUPER::stringify();
    $s .= " access=$this->{access}" if $this->{access};
    $s .= " symbols=$this->{symbols}" if $this->{symbols};
    $s .= " comment=$this->{comment}" if $this->{comment};
    $s .= " expand=$this->{expand}" if $this->{expand};
    $s .= " [";
    if( $this->{head} ) {
        for( my $i = $this->{head}; $i > 0; $i--) {
            $s .= "\tRev $i : { d=$this->{revs}[$i]->{date}";
            $s .= " l=$this->{revs}[$i]->{log}";
            $s .= " t=$this->{revs}[$i]->{text}}\n";
        }
    }
    return "$s]\n";
}

1;
