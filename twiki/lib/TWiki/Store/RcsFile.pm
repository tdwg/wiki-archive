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

---+ package TWiki::Store::RcsFile

This class is PACKAGE PRIVATE to Store, and should never be
used from anywhere else. Base class of implementations of stores
that manipulate RCS format files.

The general contract of the methods on this class and its subclasses
calls for errors to be signalled by Error::Simple exceptions.

Refer to Store.pm for models of usage.

=cut

package TWiki::Store::RcsFile;

use strict;

use File::Copy;
use File::Spec;
use File::Path;
use File::Basename;
use Assert;
use TWiki::Time;
use TWiki::Sandbox;

=pod

---++ ClassMethod new($session, $web, $topic, $attachment)

Constructor. There is one object per stored file.

Note that $web, $topic and $attachment must be untainted!

=cut

sub new {
    my( $class, $session, $web, $topic, $attachment ) = @_;
    #ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;

    $this->{web} = $web;

    if( $topic ) {
        my $rcsSubDir = ( $TWiki::cfg{RCS}{useSubDir} ? '/RCS' : '' );

        $this->{topic} = $topic;

        if( $attachment ) {

            $this->{attachment} = $attachment;

            $this->{file} = $TWiki::cfg{PubDir}.'/'.$web.'/'.
              $this->{topic}.'/'.$attachment;
            $this->{rcsFile} = $TWiki::cfg{PubDir}.'/'.
              $web.'/'.$topic.$rcsSubDir.'/'.$attachment.',v';

        } else {
            $this->{file} = $TWiki::cfg{DataDir}.'/'.$web.'/'.
              $topic.'.txt';
            $this->{rcsFile} = $TWiki::cfg{DataDir}.'/'.
              $web.$rcsSubDir.'/'.$topic.'.txt,v';
        }
    }

    return $this;
}

# Used in subclasses for late initialisation during object creation
# (after the object is blessed into the subclass)
sub init {
    my $this = shift;

    return unless $this->{topic};

    unless( -e $this->{file} ) {
        if( $this->{attachment} && !$this->isAsciiDefault() ) {
            $this->initBinary();
        } else {
            $this->initText();
        }
    }
}

# Make any missing paths on the way to this file
# SMELL: duplicates CPAN File::Tree::mkpath
sub _mkPathTo {

    my $file = shift;

    $file = TWiki::Sandbox::untaintUnchecked( $file ); 
    my $path = File::Basename::dirname($file);
    eval {
        File::Path::mkpath($path, 0, $TWiki::cfg{RCS}{dirPermission});
    };
    if ($@) {
       throw Error::Simple("RCS: failed to create ${path}: $!");
    }
}

# SMELL: this should use TWiki::Time
sub _epochToRcsDateTime {
    my( $dateTime ) = @_;
    # TODO: should this be gmtime or local time?
    my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday ) = gmtime( $dateTime );
    $year += 1900 if( $year > 99 );
    my $rcsDateTime = sprintf '%d.%02d.%02d.%02d.%02d.%02d',
      ( $year, $mon + 1, $mday, $hour, $min, $sec );
    return $rcsDateTime;
}

# filenames for lock and lease files
sub _controlFileName {
    my( $this, $type ) = @_;

    my $fn = $this->{file} || '';
    $fn =~ s/txt$/$type/;
    return $fn;
}

=pod

---++ ObjectMethod getRevisionInfo($version) -> ($rev, $date, $user, $comment)

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return info about the latest revision.

Returns (rev, date, user, comment) where rev is the number of the rev for which the info was recovered, date is the date of that rev (epoch s), user is the login name of the user who saved that rev, and comment is the comment associated with the rev.

Designed to be overridden by subclasses, which can call up to this method
if file-based rev info is required.

=cut

sub getRevisionInfo {
    my( $this ) = @_;
    my $fileDate = $this->getTimestamp();
    return ( 1, $fileDate, $TWiki::cfg{DefaultUserLogin},
             'Default revision information' );
}

=pod

---++ ObjectMethod getLatestRevision() -> $text

Get the text of the most recent revision

=cut

sub getLatestRevision {
    my $this = shift;
    return $this->_readFile( $this->{file} );
}

=pod

---++ ObjectMethod getLatestRevisionTime() -> $text

Get the time of the most recent revision

=cut

sub getLatestRevisionTime {
    my @e = stat( shift->{file} );
    return $e[9] || 0;
}

=pod

---++ ObjectMethod readMetaData($name) -> $text

Get a meta-data block for this web

=cut

sub readMetaData {
    my( $this, $name ) = @_;
    my $file = $TWiki::cfg{DataDir}.'/'.$this->{web}.'/.'.$name;
    if( -e $file ) {
        return $this->_readFile( $file );
    }
    return '';
}

=pod

---+++ ObjectMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins.

The standard is a directory named the same as "key" under
$TWiki::cfg{RCS}{WorkAreaDir}

=cut

sub getWorkArea {
    my( $this, $key ) = @_;

    # untaint and detect nasties
    $key = TWiki::Sandbox::normalizeFileName( $key );
    throw Error::Simple( "Bad work area name $key" ) unless ( $key );

    my $dir =  "$TWiki::cfg{RCS}{WorkAreaDir}/$key";

    unless( -d $dir ) {
        mkdir( $dir ) || throw Error::Simple(
            'RCS: failed to create '.$key.'work area: '.$! );
    }
    return $dir;
}

=pod

---++ ObjectMethod saveMetaData( $web, $name ) -> $text

Write a named meta-data string. If web is given the meta-data
is stored alongside a web.

=cut

sub saveMetaData {
    my ( $this, $name, $text ) = @_;

    my $file = $TWiki::cfg{DataDir}.'/'.$this->{web}.'/.'.$name;

    return $this->_saveFile( $file, $text );
}

=pod

---++ ObjectMethod getTopicNames() -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my $this = shift;

    opendir DIR, $TWiki::cfg{DataDir}.'/'.$this->{web};
    # the name filter is used to ensure we don't return filenames
    # that contain illegal characters as topic names.
    my @topicList =
      sort
        map { TWiki::Sandbox::untaintUnchecked( $_ ) }
          grep { !/$TWiki::cfg{NameFilter}/ && s/\.txt$// }
            readdir( DIR );
    closedir( DIR );
    return @topicList;
}

=pod

---++ ObjectMethod getWebNames() -> @webs

Gets a list of names of subwebs in the current web

=cut

sub getWebNames {
    my $this = shift;
    my $dir = $TWiki::cfg{DataDir}.'/'.$this->{web};
    if( opendir( DIR, $dir ) ) {
        my @tmpList =
          sort
            map { TWiki::Sandbox::untaintUnchecked( $_ ) }
              grep { !/\./ &&
                     !/$TWiki::cfg{NameFilter}/ &&
                     -d $dir.'/'.$_
                   }
                readdir( DIR );
        closedir( DIR );
        return @tmpList;
    }
    return ();
}

=pod

---++ ObjectMethod searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use searchMetaData instead).

   * =$searchString= - the search string, in egrep format if regex
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false)

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub searchInWebContent {
    my( $this, $searchString, $topics, $options ) = @_;
    ASSERT(defined $options) if DEBUG;
    my $type = $options->{type} || '';

    # I18N: 'grep' must use locales if needed,
    # for case-insensitive searching.  See TWiki::setupLocale.
    my $program = '';
    # FIXME: For Cygwin grep, do something about -E and -F switches
    # - best to strip off any switches after first space in
    # EgrepCmd etc and apply those as argument 1.
    if( $type eq 'regex' ) {
        $program = $TWiki::cfg{RCS}{EgrepCmd};
    } else {
        $program = $TWiki::cfg{RCS}{FgrepCmd};
    }

    $program =~ s/%CS{(.*?)\|(.*?)}%/$options->{casesensitive}?$1:$2/ge;
    $program =~ s/%DET{(.*?)\|(.*?)}%/$options->{files_without_match}?$2:$1/ge;

    my $sDir = $TWiki::cfg{DataDir}.'/'.$this->{web}.'/';
    my $seen = {};
    # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
    my $maxTopicsInSet = 512; # max number of topics for a grep call
    my @take = @$topics;
    my @set = splice( @take, 0, $maxTopicsInSet );
    my $sandbox = $this->{session}->{sandbox};
    while( @set ) {
        @set = map { "$sDir/$_.txt" } @set;
        my ($matches, $exit ) = $sandbox->sysCommand(
            $program,
            TOKEN => $searchString,
            FILES => \@set);
        foreach my $match ( split( /\r?\n/, $matches )) {
            if( $match =~ m/([^\/]*)\.txt(:(.*))?$/ ) {
                push( @{$seen->{$1}}, $3 );
            }
        }
        @set = splice( @take, 0, $maxTopicsInSet );
    }
    return $seen;
}

=pod

---++ ObjectMethod moveWeb(  $newWeb )

Move a web.

=cut

sub moveWeb {
    my( $this, $newWeb ) = @_;
    _moveFile( $TWiki::cfg{DataDir}.'/'.$this->{web},
               $TWiki::cfg{DataDir}.'/'.$newWeb );
    if( -d $TWiki::cfg{PubDir}.'/'.$this->{web} ) {
        _moveFile( $TWiki::cfg{PubDir}.'/'.$this->{web},
                   $TWiki::cfg{PubDir}.'/'.$newWeb );
    }
}

=pod

---++ ObjectMethod getRevision($version) -> $text

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return the latest revision.

Get the text of the given revision.

Designed to be overridden by subclasses, which can call up to this method
if the main file revision is required.

=cut

sub getRevision {
    my( $this ) = @_;
    return $this->_readFile( $this->{file} );
}

=pod

---++ ObjectMethod storedDataExists() -> $boolean

Establishes if there is stored data associated with this handler.

=cut

sub storedDataExists {
    my $this = shift;
    return -e $this->{file};
}

=pod

---++ ObjectMethod getTimestamp() -> $integer

Get the timestamp of the file
Returns 0 if no file, otherwise epoch seconds

=cut

sub getTimestamp {
    my( $this ) = @_;
    my $date = 0;
    if( -e $this->{file} ) {
        # SMELL: Why big number if fail?
        $date = (stat $this->{file})[9] || 600000000;
    }
    return $date;
}

=pod

---++ ObjectMethod restoreLatestRevision($wikiname)

Restore the plaintext file from the revision at the head.

=cut

sub restoreLatestRevision {
    my( $this, $user ) = @_;

    my $rev = $this->numRevisions();
    my $text = $this->getRevision( $rev );

    # If there is no ,v, create it
    unless( -e $this->{rcsFile} ) {
        $this->addRevisionFromText( $text, "restored", $user, time() );
    } else {
        $this->_saveFile( $this->{file}, $text );
    }
}

=pod

---++ ObjectMethod removeWeb( $web )

   * =$web= - web being removed

Destroy a web, utterly. Removed the data and attachments in the web.

Use with great care! No backup is taken!

=cut

sub removeWeb {
    my $this = shift;

    # Just make sure of the context
    ASSERT(!$this->{topic}) if DEBUG;

    _rmtree( $TWiki::cfg{DataDir}.'/'.$this->{web} );
    _rmtree( $TWiki::cfg{PubDir}.'/'.$this->{web} );
}

=pod

---++ ObjectMethod moveTopic( $newWeb, $newTopic )

Move/rename a topic.

=cut

sub moveTopic {
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};

    # Move data file
    my $new = new TWiki::Store::RcsFile( $this->{session},
                                         $newWeb, $newTopic, '' );
    _moveFile( $this->{file}, $new->{file} );

    # Move history
    _mkPathTo( $new->{rcsFile});
    if( -e $this->{rcsFile} ) {
        _moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    # Move attachments
    my $from = $TWiki::cfg{PubDir}.'/'.$this->{web}.'/'.$this->{topic};
    if( -e $from ) {
        my $to = $TWiki::cfg{PubDir}.'/'.$newWeb.'/'.$newTopic;
        _moveFile( $from, $to );
    }
}

=pod

---++ ObjectMethod copyTopic( $newWeb, $newTopic )

Copy a topic.

=cut

sub copyTopic {
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};

    my $new = new TWiki::Store::RcsFile( $this->{session},
                                         $newWeb, $newTopic, '' );

    _copyFile( $this->{file}, $new->{file} );
    if( -e $this->{rcsFile} ) {
        _copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }

    if( opendir(DIR, $TWiki::cfg{PubDir}.'/'.$this->{web}.'/'.
                  $this->{topic} )) {
        for my $att ( grep { !/^\./ } readdir DIR ) {
            $att = TWiki::Sandbox::untaintUnchecked( $att );
            my $oldAtt = new TWiki::Store::RcsFile(
                $this->{session}, $this->{web}, $this->{topic}, $att );
            $oldAtt->copyAttachment( $newWeb, $newTopic );
        }

        closedir DIR;
    }
}

=pod

---++ ObjectMethod moveAttachment( $newWeb, $newTopic, $newAttachment )

Move an attachment from one topic to another. The name is retained.

=cut

sub moveAttachment {
    my( $this, $newWeb, $newTopic, $newAttachment ) = @_;

    # FIXME might want to delete old directories if empty
    my $new = TWiki::Store::RcsFile->new( $this->{session}, $newWeb,
                                          $newTopic, $newAttachment );

    _moveFile( $this->{file}, $new->{file} );

    if( -e $this->{rcsFile} ) {
        _moveFile( $this->{rcsFile}, $new->{rcsFile} );
    }
}

=pod

---++ ObjectMethod copyAttachment( $newWeb, $newTopic )

Copy an attachment from one topic to another. The name is retained.

=cut

sub copyAttachment {
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};
    my $attachment = $this->{attachment};

    my $new = TWiki::Store::RcsFile->new( $this->{session}, $newWeb,
                                          $newTopic, $attachment );

    _copyFile( $this->{file}, $new->{file} );

    if( -e $this->{rcsFile} ) {
        _copyFile( $this->{rcsFile}, $new->{rcsFile} );
    }
}

=pod

---++ ObjectMethod isAsciiDefault (   ) -> $boolean

Check if this file type is known to be an ascii type file.

=cut

sub isAsciiDefault {
    my $this = shift;
    return ( $this->{attachment} =~
               /$TWiki::cfg{RCS}{asciiFileSuffixes}/ );
}

=pod

---++ ObjectMethod setLock($lock, $user)

Set a lock on the topic, if $lock, otherwise clear it.
$user is a wikiname.

SMELL: there is a tremendous amount of potential for race
conditions using this locking approach.

=cut

sub setLock {
    my( $this, $lock, $user ) = @_;

    $user = $this->{session}->{user} unless $user;

    my $filename = $this->_controlFileName('lock');
    if( $lock ) {
        my $lockTime = time();
        $this->_saveFile( $filename, $user."\n".$lockTime );
    } else {
        unlink $filename ||
          throw Error::Simple( 'RCS: failed to delete '.$filename.': '.$! );
    }
}

=pod

---++ ObjectMethod isLocked( ) -> ($user, $time)

See if a twiki lock exists. Return the lock user and lock time if it does.

=cut

sub isLocked {
    my( $this ) = @_;

    my $filename = $this->_controlFileName('lock');
    if ( -e $filename ) {
        my $t = $this->_readFile( $filename );
        return split( /\s+/, $t, 2 );
    }
    return ( undef, undef );
}

=pod

---++ ObjectMethod setLease( $lease )

   * =$lease= reference to lease hash, or undef if the existing lease is to be cleared.

Set an lease on the topic.

=cut

sub setLease {
    my( $this, $lease ) = @_;

    my $filename = $this->_controlFileName('lease');
    if( $lease ) {
        $this->_saveFile( $filename, join( "\n", %$lease ) );
    } elsif( -e $filename ) {
        unlink $filename ||
          throw Error::Simple( 'RCS: failed to delete '.$filename.': '.$! );
    }
}

=pod

---++ ObjectMethod getLease() -> $lease

Get the current lease on the topic.

=cut

sub getLease {
    my( $this ) = @_;

    my $filename = $this->_controlFileName('lease');
    if ( -e $filename ) {
        my $t = $this->_readFile( $filename );
        my $lease = { split( /\r?\n/, $t ) };
        return $lease;
    }
    return undef;
}

=pod

---++ ObjectMethod removeSpuriousLeases( $web )

Remove leases that are not related to a topic. These can get left behind in
some store implementations when a topic is created, but never saved.

=cut

sub removeSpuriousLeases {
    my( $this ) = @_;
    my $web = $TWiki::cfg{DataDir}.'/'.$this->{web}.'/';
    if (opendir(W, $web)) {
        foreach my $f (readdir(W)) {
            if ($f =~ /^(.*)\.lease$/) {
                if (! -e "$1.txt,v") {
                    unlink($f);
                }
            }
        }
        closedir(W);
    }
}

sub _saveStream {
    my( $this, $fh ) = @_;

    ASSERT($fh) if DEBUG;

    _mkPathTo( $this->{file} );
    open( F, '>'.$this->{file} ) ||
        throw Error::Simple( 'RCS: open '.$this->{file}.' failed: '.$! );
    binmode( F ) ||
      throw Error::Simple( 'RCS: failed to binmode '.$this->{file}.': '.$! );
    my $text;
    binmode(F);
    while( read( $fh, $text, 1024 )) {
        print F $text;
    }
    close(F) ||
        throw Error::Simple( 'RCS: close '.$this->{file}.' failed: '.$! );;

    chmod( $TWiki::cfg{RCS}{filePermission}, $this->{file} );

    return '';
}

sub _copyFile {
    my( $from, $to ) = @_;

    _mkPathTo( $to );
    unless( File::Copy::copy( $from, $to ) ) {
        throw Error::Simple( 'RCS: copy '.$from.' to '.$to.' failed: '.$! );
    }
}

sub _moveFile {
    my( $from, $to ) = @_;

    _mkPathTo( $to );
    unless( File::Copy::move( $from, $to ) ) {
        throw Error::Simple( 'RCS: move '.$from.' to '.$to.' failed: '.$! );
    }
}

sub _saveFile {
    my( $this, $name, $text ) = @_;

    _mkPathTo( $name );

    open( FILE, '>'.$name ) ||
      throw Error::Simple( 'RCS: failed to create file '.$name.': '.$! );
    binmode( FILE ) ||
      throw Error::Simple( 'RCS: failed to binmode '.$name.': '.$! );
    print FILE $text;
    close( FILE) ||
      throw Error::Simple( 'RCS: failed to create file '.$name.': '.$! );

    return undef;
}

sub _readFile {
    my( $this, $name ) = @_;
    my $data;
    if( open( IN_FILE, '<', $name )) {
        binmode( IN_FILE );
        local $/ = undef;
        $data = <IN_FILE>;
        close( IN_FILE );
    }
    $data ||= '';
    return $data;
}

sub _mkTmpFilename {
    my $tmpdir = File::Spec->tmpdir();
    my $file = _mktemp( 'twikiAttachmentXXXXXX', $tmpdir );
    return File::Spec->catfile($tmpdir, $file);
}

# Adapted from CPAN - File::MkTemp
sub _mktemp {
    my ($template,$dir,$ext,$keepgen,$lookup);
    my (@template,@letters);

    ASSERT(@_ == 1 || @_ == 2 || @_ == 3) if DEBUG;

    ($template,$dir,$ext) = @_;
    @template = split //, $template;

    ASSERT($template =~ /XXXXXX$/) if DEBUG;

    if ($dir){
        ASSERT(-e $dir) if DEBUG;
    }

    @letters =
      split(//,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');

    $keepgen = 1;

    while ($keepgen){
        for (my $i = $#template; $i >= 0 && ($template[$i] eq 'X'); $i--){
            $template[$i] = $letters[int(rand 52)];
        }

        undef $template;

        $template = pack 'a' x @template, @template;

        $template = $template . $ext if ($ext);

        if ($dir){
            $lookup = File::Spec->catfile($dir, $template);
            $keepgen = 0 unless (-e $lookup);
        } else {
            $keepgen = 0;
        }

        next if $keepgen == 0;
    }

    return($template);
}

# remove a directory and all subdirectories.
sub _rmtree {
    my $root = shift;

    if( opendir( D, $root ) ) {
        foreach my $entry ( grep { !/^\.+$/ } readdir( D ) ) {
            $entry =~ /^(.*)$/;
            $entry = $root.'/'.$1;
            if( -d $entry ) {
                _rmtree( $entry );
            } else {
                unless( unlink( $entry ) ) {
                    throw Error::Simple( 'RCS: Failed to delete file '.
                                           $entry.': '.$! );
                }
            }
        }
        closedir(D);

        rmdir( $root ) ||
          throw Error::Simple( 'RCS: Failed to delete '.$root.': '.$! );
    }
}

=pod

---++ ObjectMethod getStream() -> \*STREAM

Return a text stream that will supply the text stored in the topic.

=cut

sub getStream {
    my( $this ) = shift;
    my $strm;
    unless( open( $strm, '<'.$this->{file} )) {
        throw Error::Simple( 'RCS: stream open '.$this->{file}.
                               ' failed: '.$! );
    }
    return $strm;
}

=pod

---++ ObjectMethod numRevisions() -> $integer

Must be provided by subclasses.

Find out how many revisions there are. If there is a problem, such
as a nonexistent file, returns 0.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod initBinary()

Initialise a binary file.

Must be provided by subclasses.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod initText()

Initialise a text file.

Must be provided by subclasses.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod addRevisionFromText($text, $comment, $user, $date)

Add new revision. Replace file with text.
   * =$text= of new revision
   * =$comment= checkin comment
   * =$user= is a wikiname.
   * =$date= in epoch seconds; may be ignored

*Virtual method* - must be implemented by subclasses

=pod

---++ ObjectMethod addRevisionFromStream($fh, $comment, $user, $date)

Add new revision. Replace file with contents of stream.
   * =$fh= filehandle for contents of new revision
   * =$comment= checkin comment
   * =$user= is a wikiname.
   * =$date= in epoch seconds; may be ignored

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod replaceRevision($text, $comment, $user, $date)

Replace the top revision.
   * =$text= is the new revision
   * =$date= is in epoch seconds.
   * =$user= is a wikiname.
   * =$comment= is a string

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod deleteRevision()

Delete the last revision - do nothing if there is only one revision

*Virtual method* - must be implemented by subclasses

=cut to implementation

=pod

---++ ObjectMethod revisionDiff (   $rev1, $rev2, $contextLines  ) -> \@diffArray

rev2 newer than rev1.
Return reference to an array of [ diffType, $right, $left ]

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod getRevision($version) -> $text

Get the text for a given revision. The version number must be an integer.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod getRevisionAtTime($time) -> $rev

Get a single-digit version number for the rev that was alive at the
given epoch-secs time, or undef it none could be found.

*Virtual method* - must be implemented by subclasses

=cut


=pod

---++ ObjectMethod getAttachmentAttributes($web, $topic, $attachment)

returns [stat] for any given web, topic, $attachment
SMELL - should this return a hash of arbitrary attributes so that 
SMELL + attributes supported by the underlying filesystem are supported
SMELL + (eg: windows directories supporting photo "author", "dimension" fields)

=cut

sub getAttachmentAttributes {
	my( $this, $web, $topic, $attachment ) = @_;
    ASSERT(defined $attachment) if DEBUG;
	
	my $dir = dirForTopicAttachments($web, $topic);
   	my @stat = stat ($dir."/".$attachment);

	return @stat;
}

=pod

sub _constructAttributesForAutoAttached
as long as stat is defined, return an emulated set of attributes for that attachment.

=cut

sub _constructAttributesForAutoAttached {
    my ($file, $stat) = @_;

    my %pairs = (
        name    => $file,
        version => '',
        path    => $file,
        size    => $stat->[7],
        date    => $stat->[9], 
        user    => 'UnknownUser', 
        comment => '',
        attr    => '',
        autoattached => '1'
       );

    if ($#$stat > 0) {
        return \%pairs;
    } else {
        return undef;
    }
}


=pod

---++ ObjectMethod getAttachmentList($web, $topic)

returns {} of filename => { key => value, key2 => value } for any given web, topic
Ignores files starting with _ or ending with ,v

=cut

sub getAttachmentList {
	my( $this, $web, $topic ) = @_;
	my $dir = dirForTopicAttachments($web, $topic);
		
    opendir DIR, $dir || return '';
    my %attachmentList = ();
    my @files = sort grep { m/^[^\.*_]/ } readdir( DIR );
    @files = grep { !/.*,v/ } @files;
    foreach my $attachment ( @files ) {
    	my @stat = stat ($dir."/".$attachment);
        $attachmentList{$attachment} = _constructAttributesForAutoAttached($attachment, \@stat);
    }
    closedir( DIR );
    return %attachmentList;
}

sub dirForTopicAttachments {
    my ($web, $topic ) = @_;
    return $TWiki::cfg{PubDir}.'/'.$web.'/'.$topic;
}

=pod

---++ ObjectMethod stringify()

Generate string representation for debugging

=cut

sub stringify {
    my $this = shift;

    return $this->{web}.'.'.
      ($this->{topic} || '{no topic}').
        ($this->{attachment} ? ':'.$this->{attachment} : '').
          $this->{file}.(-e $this->{file} ? '(e)' : '').
            '/'.$this->{rcsFile}.(-e $this->{rcsFile} ? '(e)' : '');
}

# Chop out recognisable path components to prevent hacking based on error
# messages
sub _hidePath {
    my ( $this, $erf ) = @_;
    $erf =~ s#.*(/\w+/\w+\.[\w,]*)$#...$1#;
    return $erf;
}

1;
