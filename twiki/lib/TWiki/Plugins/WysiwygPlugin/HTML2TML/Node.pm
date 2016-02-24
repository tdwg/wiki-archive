# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

# The generator works by expanding to "decorated" text, where the decorators
# are non-printable characters. These characters act express format
# requirements - for example, the need to have a newline before some text,
# or the need for a space. Whitespace is collapsed down to the minimum that
# satisfies the format requirements.

=pod

---+ package TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;

Object for storing a parsed HTML tag, and processing it
to generate TML from the parse tree.

See also TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf

=cut

package TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;

use strict;

use TWiki::Func; # needed for regular expressions

use TWiki::Plugins::WysiwygPlugin::HTML2TML::WC;
@TWiki::Plugins::WysiwygPlugin::HTML2TML::Node::ISA = qw( WC );

use HTML::Entities;

use vars qw( $reww );

=pod

---++ ObjectMethod new( $context, $tag, \%attrs )

Construct a new HTML tag node using the given tag name
and attribute hash.

=cut

sub new {
    my( $class, $context, $tag, $attrs ) = @_;

    my $this = {};

    $this->{context} = $context;
    $this->{tag} = $tag;
    $this->{attrs} = {};
    if( $attrs ) {
        foreach my $attr ( keys %$attrs ) {
            $this->{attrs}->{$attr} = $attrs->{$attr};
        }
    }
    $this->{children} = [];

    return bless( $this, $class );
}

# debug
sub stringify {
    my( $this, $shallow ) = @_;
    my $r = '';
    if( $this->{tag} ) {
        $r .= '<'.$this->{tag};
        foreach my $attr ( keys %{$this->{attrs}} ) {
            $r .= " ".$attr."='".$this->{attrs}->{$attr}."'";
        }
        $r .= '>';
    }
    if( $shallow ) {
        $r .= '...';
    } else {
        foreach my $kid ( @{$this->{children}} ) {
            $r .= $kid->stringify();
        }
    }
    if( $this->{tag} ) {
        $r .= '</'.lc($this->{tag}).'>';
    }
    return $r;
}

=pod

---++ ObjectMethod addChild( $node )

Add a child node to the ordered list of children of this node

=cut

sub addChild {
    my( $this, $node ) = @_;

    push( @{$this->{children}}, $node );
}

# top and tail a string
sub _trim {
    my $s = shift;

    $s =~ s/^[ \t\n$WC::CHECKn$WC::CHECKw$WC::CHECKs]+//o;
    $s =~ s/[ \t\n$WC::CHECKn$WC::CHECKw$WC::CHECKs]+$//o;
    return $s;
}

=pod

---++ ObjectMethod rootGenerate($opts) -> $text

Generates TML from this HTML node. The generation is done
top down and bottom up, so that higher level nodes can make
decisions on whether to allow TML conversion in lower nodes,
and lower level nodes can constrain conversion in higher level
nodes.

$opts is a bitset. $WC::VERY_CLEAN will cause the generator
to drop unrecognised HTML (e.g. divs and spans that don't
generate TML)

=cut

sub rootGenerate {
    my( $this, $opts ) = @_;

    $this->cleanParseTree();

    my( $f, $tml ) = $this->generate($opts);

    # isolate whitespace checks and convert to $NBSP
    $tml =~ s/$WC::CHECKw$WC::CHECKw+/$WC::CHECKw/go;
    $tml =~ s/([$WC::CHECKn$WC::CHECKs$WC::NBSP$WC::NBBR\s])$WC::CHECKw/$1/go;
    $tml =~ s/$WC::CHECKw([$WC::CHECKn$WC::CHECKs$WC::NBSP$WC::NBBR\s])/$1/go;
    $tml =~ s/($WC::CHECKw)+/$WC::NBSP/go;

    # isolate $CHECKs and convert to $NBSP
    $tml =~ s/$WC::CHECKs$WC::CHECKs+/$WC::CHECKs/go;
    $tml =~ s/([ $WC::NBSP])$WC::CHECKs/$1/go;
    $tml =~ s/$WC::CHECKs( |$WC::NBSP)/$1/go;
    $tml =~ s/($WC::CHECKs)+/$WC::NBSP/go;

    # isolate $CHECKn and convert to $NBBR
    $tml =~ s/$WC::CHECKn$WC::CHECKn+/$WC::CHECKn/go;
    $tml =~ s/^$WC::CHECKn//gom;
    $tml =~ s/$WC::CHECKn$//gom;
    $tml =~ s/(?<=$WC::NBBR)$WC::CHECKn//gom;
    $tml =~ s/$WC::CHECKn(?=$WC::NBBR)//gom;
    $tml =~ s/($WC::CHECKn)+/$WC::NBBR/gos;

    # isolate $NBBR and convert to \n
    $tml =~ s/\n*$WC::NBBR\n*/$WC::NBBR/gs;
    $tml =~ s/$WC::NBBR$WC::NBBR+/$WC::NBBR$WC::NBBR/go;
    $tml =~ s/$WC::NBBR/\n/go;

    # isolate $NBSP and convert to space
    $tml =~ s/ +$WC::NBSP/$WC::NBSP/go;
    $tml =~ s/$WC::NBSP +/$WC::NBSP/go;
    $tml =~ s/$WC::NBSP/ /go;

    $tml =~ s/$WC::CHECK1$WC::CHECK1+/$WC::CHECK1/g;
    $tml =~ s/$WC::CHECK2$WC::CHECK2+/$WC::CHECK2/g;
    $tml =~ s/$WC::CHECK2$WC::CHECK1/$WC::CHECK2/g;

    $tml =~ s/(^|[\s\(])$WC::CHECK1/$1/gso;
    $tml =~ s/$WC::CHECK2($|[\s\,\.\;\:\!\?\)\*])/$1/gso;

    $tml =~ s/$WC::CHECK1(\s|$)/$1/gso;
    $tml =~ s/(^|\s)$WC::CHECK2/$1/gso;

    $tml =~ s/$WC::CHECK1/ /go;
    $tml =~ s/$WC::CHECK2/ /go;

    # Top and tail, and terminate with a single newline
    $tml =~ s/^\n*//s;
    $tml =~ s/\s*$/\n/s;

    return $tml;
}

# the actual generate function. rootGenerate is only applied to the root node.
sub generate {
    my( $this, $options ) = @_;
    my $fn;
    my $flags;
    my $text;

    my $tag = uc( $this->{tag} );
    if( $options & $WC::NO_HTML ) {
        # NO_HTML implies NO_TML
        my $brats = $this->_flatten( $options );
        if( $this->{tag} && $WC::BREAK_BEFORE{$this->{tag}} ) {
            $brats = "\n".$brats;
        }
        return ( 0, $brats );
    }

    if( $options & $WC::NO_TML ) {
        return ( 0, $this->stringify() );
    }

    # make the names of the function versions
    $tag =~ s/!//; # DOCTYPE
    my $tmlFn = '_handle'.$tag;

    # See if we have a TML translation function for this tag
    # the translation functions will work out the rendering
    # of their own children.
    if( $this->{tag} && defined( &$tmlFn ) ) {
        no strict 'refs';
        ( $flags, $text ) = &$tmlFn( $this, $options );
        use strict 'refs';
        # if the function returns undef, drop through
        return ( $flags, $text ) if defined $text;
    }

    # No translation, so we need the text of the children
    ( $flags, $text ) = $this->_flatten( $options );

    # just return the text if there is no tag name
    return ( $flags, $text ) unless $this->{tag};

    return $this->_defaultTag( $options );
}

# Return the children flattened out subject to the options
sub _flatten {
    my( $this, $options ) = @_;
    my $text = '';
    my $flags = 0;

    foreach my $kid ( @{$this->{children}} ) {
        my( $f, $t ) = $kid->generate( $options );
        if( $text && $text =~ /\w$/ && $t =~ /^\w/ ) {
            # if the last child ends in a \w and this child
            # starts in a \w, we need to insert a space
            $text .= ' ';
        }
        $text .= $t;
        $flags |= $f;
    }
    return ( $flags, $text );
}

# $cutClasses is an RE matching class names to cut
sub _htmlParams {
    my ( $attrs, $options, $cutClasses ) = @_;
    my @params;

    foreach my $key ( keys %$attrs ) {
        next unless $key;
        if( $key eq 'class' ) {
            # if cleaning aggressively, remove class attributes completely
            next if ($options & $WC::VERY_CLEAN);
            if( $cutClasses ) {
                $attrs->{$key} ||= '';
                # tidy up the list of class names
                my @classes = grep { !/^($cutClasses)$/ }
                  split(/\s+/, $attrs->{$key} );
                $attrs->{$key} = join(' ', @classes);
                next unless( $attrs->{$key} =~ /\S/);
            }
        }
        my $q = $attrs->{$key} =~ /"/ ? "'" : '"';
        push( @params, "$key=$q$attrs->{$key}$q" );
    }
    my $p = join( ' ', @params );
    return '' unless $p;
    return ' '.$p;
}

# generate the default representation of an HTML tag
sub _defaultTag {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatten( $options );
    my $tag = lc( $this->{tag} );
    my $p = _htmlParams( $this->{attrs}, $options );
    if( $text =~ /^\s+$/ ) {
        return ( $flags, '<'.$tag.$p.' />' );
    } else {
        return ( $flags, '<'.$tag.$p.'>'.$text.'</'.$tag.'>' );
    }
}

# perform conversion on a list type
sub _convertList {
    my( $this, $indent ) = @_;
    my $basebullet;
    my $isdl = ( lc( $this->{tag} ) eq 'dl' );

    if( $isdl ) {
        $basebullet = '';
    } elsif( lc( $this->{tag} ) eq 'ol' ) {
        $basebullet = '1';
    } else {
        $basebullet = '*';
    }

    my $f;
    my $text = '';
    my $pendingDT = 0;
    foreach my $kid ( @{$this->{children}} ) {
        # be tolerant of dl, ol and ul with no li
        if( $kid->{tag} =~ m/^[dou]l$/i ) {
            $text .= $kid->_convertList( $indent."   " );
            next;
        }
        next unless $kid->{tag} =~ m/^(dt|dd|li)$/i;
        if( $isdl && ( lc( $kid->{tag} ) eq 'dt' )) {
            # DT, set the bullet type for subsequent DT
            $basebullet = $kid->_flatten( $WC::NO_BLOCK_TML ).':';
            $basebullet =~ s/$WC::CHECKn/ /g;
            if( $basebullet =~ /[$WC::CHECKw ]/ ) {
                $basebullet = "\$ $basebullet";
            }
            $pendingDT = 1; # remember in case there is no DD
            next;
        }
        my $bullet = $basebullet;
        if( $basebullet eq '1' && $kid->{attrs}->{type} ) {
            $bullet = $kid->{attrs}->{type}.'.';
        }
        my $spawn = '';
        foreach my $grandkid ( @{$kid->{children}} ) {
            my $t;
            if( $grandkid->{tag} =~ /^[dou]l$/i ) {
                $spawn = _trim( $spawn );
                $t = $grandkid->_convertList( $indent."   " );
            } else {
                ( $f, $t ) = $grandkid->generate( $WC::NO_BLOCK_TML );
                $t =~ s/$WC::CHECKn/ /g;
            }
            $spawn .= $t;
        }
        $spawn =~ s/ +$//;
        $text .= $WC::CHECKn.$indent.$bullet.$WC::CHECKs.$spawn.$WC::CHECKn;
        $pendingDT = 0;
        $basebullet = '' if $isdl;
    }
    if( $pendingDT ) {
        # DT with no corresponding DD
        $text .= $WC::CHECKn.$indent.$basebullet.$WC::CHECKn;
    }
    return $text;
}

# probe down into a list type to determine if it
# can be converted to TML.
sub _isConvertableList {
    my( $this, $options ) = @_;

    foreach my $kid ( @{$this->{children}} ) {
        # check for malformed list. We can still handle it,
        # by simply ignoring illegal text.
        # be tolerant of dl, ol and ul with no li
        if( $kid->{tag} =~ m/^[dou]l$/i ) {
            return 0 unless $kid->_isConvertableList( $options );
            next;
        }
        next unless( $kid->{tag} =~ m/^(dt|dd|li)$/i );
        unless( $kid->_isConvertableListItem( $options, $this )) {
            return 0;
        }
    }
    return 1;
}

# probe down into a list item to determine if the
# containing list can be converted to TML.
sub _isConvertableListItem {
    my( $this, $options, $parent ) = @_;
    my( $flags, $text );

    if( lc( $parent->{tag} ) eq 'dl' ) {
        return 0 unless( $this->{tag} =~ /^d[td]$/i );
    } else {
        return 0 unless( lc( $this->{tag} ) eq 'li' );
    }

    foreach my $kid ( @{$this->{children}} ) {
        if( $kid->{tag} =~ /^[oud]l$/i ) {
            unless( $kid->_isConvertableList( $options )) {
                return 0;
            }
        } else {
            ( $flags, $text ) = $kid->generate( $options );
            if( $flags & $WC::BLOCK_TML ) {
                return 0;
            }
        }
    }
    return 1;
}

# probe down into a list type to determine if it
# can be converted to TML.
sub _isConvertableTable {
    my( $this, $options, $table ) = @_;
    my @process = ( @{$this->{children}} );
    foreach my $kid ( @{$this->{children}} ) {
        if( $kid->{tag} =~ /^(colgroup|thead|tbody|tfoot|col)$/i ) {
            return 0 unless( $kid->_isConvertableTable( $options, $table ));
        } elsif( !$kid->{tag} ) {
            next;
        } else {
            return 0 unless( lc( $kid->{tag} ) eq 'tr' );
            my $row = $kid->_isConvertableTableRow( $options );
            return 0 unless $row;
            push( @$table, $row );
        }
    }
    return 1;
}

# probe down into a list item to determine if the
# containing table can be converted to TML.
sub _isConvertableTableRow {
    my( $this, $options ) = @_;
    my( $flags, $text );

    my @row;
    foreach my $kid ( @{$this->{children}} ) {
        if( lc( $kid->{tag} ) eq 'th' ) {
            ( $flags, $text ) = $kid->_flatten( $options );
            $text = _trim( $text );
            $text = ' *'._trim( $text ).'* ' if $text;
        } elsif(lc( $kid->{tag} ) eq 'td' ) {
            ( $flags, $text ) = $kid->_flatten( $options );
            $text = _trim( $text );
            $text = ' '.$text.' ' if $text;
        } elsif( !$kid->{tag} ) {
            next;
        } else {
            # some other sort of (unexpected) tag
            return 0;
        }
        return 0 if( $flags & $WC::BLOCK_TML );
        $text = '' if $text =~ /%SPAN%/;
        # tidy up whitespace, including \ns. We user [\0- ] to catch
        # all the WC:: special characters as well.
        $text =~ s/^[\0- ]*(.+?)[\0- ]*$/ $1 /;
        if( $kid->{attrs} ) {
            my $a = _deduceAlignment( $kid );
            if( $text && $a eq 'right' ) {
                $text = ' '.$text;
            } elsif( $text && $a eq 'center' ) {
                $text = ' '.$text.' ';
            } elsif( $text && $a eq 'left' ) {
                $text .= ' ';
            }
            if( $kid->{attrs}->{rowspan} && $kid->{attrs}->{rowspan} > 1 ) {
                return 0;
            }
        }
        push( @row, $text );
    }
    return \@row;
}

sub _deduceAlignment {
    my $td = shift;

    if( $td->{attrs}->{align} ) {
        return lc( $td->{attrs}->{align} );
    } else {
        if( $td->{attrs}->{style} &&
              $td->{attrs}->{style} =~ /text-align\s*:\s*(left|right|center)/ ) {
            return $1;
        }
        if( $td->{attrs}->{class} &&
              $td->{attrs}->{class} =~ /align-(left|right|center)/ ) {
            return $1;
        }
    }
    return '';
}

# convert a heading tag
sub _H {
    my( $this, $options, $depth ) = @_;
    my( $flags, $contents ) = $this->_flatten( $options );
    return ( 0, undef ) if( $flags & $WC::BLOCK_TML );
    my $notoc = '';
    if( $this->{attrs}->{class} &&
          $this->{attrs}->{class} =~ /\bnotoc\b/ ) {
        $notoc = '!!';
    }
    $contents =~ s/^\s*/ /;
    my $res = $WC::CHECKn.'---'.('+' x $depth).$notoc.
      $WC::CHECKs.$contents.$WC::CHECKn;
    return ( $flags | $WC::BLOCK_TML, $res );
}

# generate an emphasis
sub _emphasis {
    my( $this, $options, $ch ) = @_;
    my( $flags, $contents ) = $this->_flatten( $options | $WC::NO_BLOCK_TML );
    return ( 0, undef ) if( !defined( $contents ) || ( $flags & $WC::BLOCK_TML ));
    $contents = _trim( $contents );
    return (0, undef) if( $contents =~ /^</ || $contents =~ />$/ );
    return (0, '') unless( $contents =~ /\S/ );
    return ( $flags, $WC::CHECKw.$ch.$contents.$ch.$WC::CHECK2 );
}

# pseudo-tags that may leak through in TWikiVariables
# We have to handle this to avoid a matching close tag </nop>
sub _handleNOP {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatten( $options );
    return ($flags, '<nop>'.$text);
}

sub _handleNOPRESULT {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatten( $options );
    return ($flags, '<nop>'.$text);
}

# tags we ignore completely (contents as well)
sub _handleDOCTYPE { return ( 0, '' ); }

sub _handleVERBATIM {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatten( $WC::NO_TML | $WC::NO_HTML );

    $text =~ s!<br( /)?>!$WC::NBBR!gi;
    $text =~ s!<p( /)?>!$WC::NBBR!gi;
    $text =~ s!</(p|br)>!!gi;
    $text = HTML::Entities::decode_entities( $text );
    $text =~ s/ /$WC::NBSP/g;
    $text =~ s/$WC::CHECKn/$WC::NBBR/g;
    my $p = _htmlParams( $this->{attrs}, $options, 'TMLverbatim' );
    return ( $WC::BLOCK_TML,
             "$WC::CHECKn<verbatim$p>$WC::CHECKn".$text."$WC::CHECKn</verbatim>$WC::CHECKn" );
}

sub _LIST {
    my( $this, $options ) = @_;
    if( ( $options & $WC::NO_BLOCK_TML ) ||
        !$this->_isConvertableList( $options | $WC::NO_BLOCK_TML )) {
        return ( 0, undef );
    }
    return ( $WC::BLOCK_TML, $this->_convertList( "   " ));
}

# Performs initial cleanup of the parse tree before generation. Walks the
# tree, making parent links and removing attributes that don't add value.
# This simplifies determining whether a node is to be kept, or flattened
# out.
# $opts may include $WC::VERY_CLEAN
sub cleanNode {
    my( $this, $opts ) = @_;
    my $a;

    # Always delete these attrs
    foreach $a qw( lang _moz_dirty ) {
        delete $this->{attrs}->{$a}
          if( defined( $this->{attrs}->{$a} ));
    }

    # Delete these attrs if their value is empty
    foreach $a qw( class style ) {
        if( defined( $this->{attrs}->{$a} ) &&
              $this->{attrs}->{$a} !~ /\S/ ) {
            delete $this->{attrs}->{$a};
        }
    }
}

######################################################
# Handlers for different HTML tag types. Each handler returns
# a pair (flags,text) containing the result of the expansion.
#
# There are four ways of handling a tag:
# 1. Return (0,undef) which will cause the tag to be output
#    as HTML tags.
# 2. Return _flatten which will cause the tag to be ignored,
#    but the content expanded
# 3. Return (0, '') which will cause the tag not to be output
# 4. Something else more complex
#
# Note that tags like TFOOT and DT are handled inside the table
# and list processors.
# They only have handler methods in case the tag is seen outside
# the content of a table or list. In this case they are usually
# simply removed from the output.
#
sub _handleA {
    my( $this, $options ) = @_;

    my( $flags, $text ) = $this->_flatten( $options | $WC::NO_BLOCK_TML );
    if( $text && $text =~ /\S/ && $this->{attrs}->{href}) {
        # there's text and an href
        my $href = $this->{attrs}->{href};
        if( $this->{context} && $this->{context}->{rewriteURL} ) {
            $href = &{$this->{context}->{rewriteURL}}(
                $href, $this->{context} );
        }
        $reww = TWiki::Func::getRegularExpression('wikiWordRegex')
          unless $reww;
        my $nop = ($options & $WC::NOP_ALL) ? '<nop>' : '';
        if( $href =~ /^(\w+\.)?($reww)(#\w+)?$/ ) {
            my $web = $1 || '';
            my $topic = $2;
            my $anchor = $3 || '';
            my $cleantext = $text;
            $cleantext =~ s/<nop>//g;
            $cleantext =~ s/^$this->{context}->{web}\.//;

            # if the clean text is the known topic we can ignore it
            if( ($cleantext eq $href || $href =~ /\.$cleantext$/)) {
                return (0, $WC::CHECK1.$nop.$web.$topic.$anchor.$WC::CHECK2);
            }
        }

        if( $href =~ /${WC::PROTOCOL}[^?]*$/ && $text eq $href ) {
            return (0, $WC::CHECK1.$nop.$text.$WC::CHECK2);
        }
        if( $text eq $href ) {
            return (0, $WC::CHECKw.'['.$nop.'['.$href.']]' );
        }
        return (0, $WC::CHECKw.'['.$nop.'['.$href.']['.$text.
                  ']]' );
    } elsif( $this->{attrs}->{name} ) {
        # allow anchors to be expanded normally. This won't generate
        # wiki anchors, but it's a small price to pay - it would
        # be too complex to generate wiki anchors, given their
        # line-oriented nature.
        return (0, undef);
    }
    # Otherwise generate nothing
    return (0, '');
}

sub _handleABBR { return _flatten( @_ ); };
sub _handleACRONYM { return _flatten( @_ ); };
sub _handleADDRESS { return _flatten( @_ ); };
sub _handleAPPLET { return( 0, '' ); };
sub _handleAREA { return( 0, '' ); };

sub _handleB { return _handleSTRONG( @_ ); }
sub _handleBASE { return ( 0, '' ); }
sub _handleBASEFONT { return ( 0, '' ); }
sub _handleBDO { return( 0, '' ); };
sub _handleBIG { return( 0, '' ); };
# BLOCKQUOTE
sub _handleBODY { return _flatten( @_ ); }
# BUTTON

sub _handleBR {
    my( $this, $options ) = @_;
    my($f, $kids ) = $this->_flatten( $options );
    if( ( $options & $WC::NO_BLOCK_TML ) ||
        $this->{prev} && !$this->{prev}->{tag} &&
        $this->{prev}->{text} =~ /\S/ &&
        $this->{next} && !$this->{next}->{tag} &&
        $this->{prev}->{text} =~ /\S/ ) {
        my $reason = '';
#        if ( $options & $WC::NO_BLOCK_TML ) {
#            $reason = 'A';
#        } else {
#            $reason = 'B'.$this->{prev}->{text}.';'.$this->{next}->{text};
#        }
        # Special case; if the immediately siblings are text
        # nodes, then we have to use a <br>
        return (0, '<br '.$reason.'/>'.$kids);
    }
    return ($f, $WC::NBBR.$kids);
}

# CAPTION
# CENTER
# CITE

sub _handleCODE {
    my( $this, $options ) = @_;
    if( scalar( @{$this->{children}} ) == 1 &&
        $this->{children}->[0]->{tag} =~ /^(b|strong)$/i ) {
        return _emphasis( $this->{children}->[0], $options, '==' );
    }
    return _emphasis( @_, '=' );
}

sub _handleCOL { return _flatten( @_ ); };
sub _handleCOLGROUP { return _flatten( @_ ); };
sub _handleDD { return _flatten( @_ ); };
sub _handleDEL { return _flatten( @_ ); };
sub _handleDFN { return _flatten( @_ ); };
# DIR

sub _handleDIV {
    my( $this, $options ) = @_;
    if( defined( $this->{attrs}->{class} ) &&
          $this->{attrs}->{class} =~ /\bTMLnoautolink\b/ ) {
        my( $flags, $text ) = $this->_flatten( $options );
        my $p = _htmlParams( $this->{attrs}, $options, 'TMLnoautolink' );
        return ($WC::BLOCK_TML, "$WC::CHECKn<noautolink$p>$WC::CHECKn".$text.
                "$WC::CHECKn</noautolink>$WC::CHECKn");
    }

    return (0, undef);
}

sub _handleDL { return _LIST( @_ ); }
sub _handleDT { return _flatten( @_ ); };

sub _handleEM {
    my( $this, $options ) = @_;
    if( scalar( @{$this->{children}} ) == 1 &&
        $this->{children}->[0]->{tag} =~ /^(b|strong)$/i ) {
        return _emphasis( $this->{children}->[0], $options, '__' );
    }
    return _emphasis( @_, '_' );
}

sub _handleFIELDSET { return _flatten( @_ ); };
sub _handleFONT {
    my( $this, $options ) = @_;
    if( defined( $this->{attrs}->{class} ) &&
          scalar( %{$this->{attrs}}) == 1 &&
            ($options & $WC::VERY_CLEAN)) {
        # Only defines class. Ignore it if we are cleaning.
        return $this->_flatten( $options );
    }
    return ( 0, undef );
};
# FORM
sub _handleFRAME    { return _flatten( @_ ); };
sub _handleFRAMESET { return _flatten( @_ ); };
sub _handleHEAD     { return ( 0, '' ); }

sub _handleHR {
    my( $this, $options ) = @_;

    my( $f, $kids ) = $this->_flatten( $options );
    return ($f, '<hr />'.$kids) if( $options & $WC::NO_BLOCK_TML );
    return ( $f | $WC::BLOCK_TML, $WC::CHECKn.'---'.$WC::CHECKn.$kids);
}

sub _handleHTML   { return _flatten( @_ ); }
sub _handleH1     { return _H( @_, 1 ); }
sub _handleH2     { return _H( @_, 2 ); }
sub _handleH3     { return _H( @_, 3 ); }
sub _handleH4     { return _H( @_, 4 ); }
sub _handleH5     { return _H( @_, 5 ); }
sub _handleH6     { return _H( @_, 6 ); }
sub _handleI      { return _handleEM( @_ ); }
sub _handleIFRAME { return( 0, '' ); };

sub _handleIMG {
    my( $this, $options ) = @_;

    if( $this->{context} && $this->{context}->{rewriteURL} ) {
        my $href = $this->{attrs}->{src};
        $href = &{$this->{context}->{rewriteURL}}(
            $href, $this->{context} );
        $this->{attrs}->{src} = $href;
    }

    return (0, undef) unless $this->{context} &&
      $this->{context}->{convertImage};

    my $alt = &{$this->{context}->{convertImage}}(
        $this->{attrs}->{src},
        $this->{context} );
    if( $alt ) {
        return (0, " $alt ");
    }
    return ( 0, undef );
}

sub _handleINPUT {
    my( $this, $options ) = @_;
    if( $this->{attrs}->{class} &&
          $this->{attrs}->{class} =~ /\bTMLvariable\b/ ) {
        my $text = $this->{attrs}->{value} || '';
        my $var = _trim($text);
        my $nop = ($options & $WC::NOP_ALL) ? '<nop>' : '';
        # don't create unnamed variables
        $var = '%'.$nop.$var.'%' if( $var );
        my $flags;
        ( $flags, $text ) = $this->_flatten( $options | $WC::NO_BLOCK_TML );
        return (0, $var.$text);
    }
    if( $options & $WC::VERY_CLEAN ) {
        return $this->_flatten( $options );
    }
    return (0, undef);
}

# INS
sub _handleISINDEX  { return( 0, '' ); };
sub _handleKBD      { return _handleTT( @_ ); }
sub _handleLABEL    { return( 0, '' ); };
# LI
sub _handleLINK     { return( 0, '' ); };
# MAP
# MENU
sub _handleMETA     { return ( 0, '' ); }
sub _handleNOFRAMES { return ( 0, '' ); }
sub _handleNOSCRIPT { return ( 0, '' ); }
sub _handleOBJECT   { return ( 0, '' ); }
sub _handleOL       { return _LIST( @_ ); }
# OPTGROUP
# OPTION

sub _handleP {
    my( $this, $options ) = @_;

    my( $f, $kids ) = $this->_flatten( $options );
    return ($f, '<p />'.$kids) if( $options & $WC::NO_BLOCK_TML );
    return ($f | $WC::BLOCK_TML, $WC::NBBR.$WC::NBBR.$kids);
}

sub _handlePARAM { return ( 0, '' ); }

sub _handlePRE {
    my( $this, $options ) = @_;

    if( $this->{attrs}->{class} &&
        $this->{attrs}->{class} =~ /\bTMLverbatim\b/ ) {
        return $this->_handleVERBATIM( $options );
    }

    # Note: can't use CGI::pre because it won't put the newlines that
    # twiki needs in
    unless( $options & $WC::NO_BLOCK_TML ) {
        my( $flags, $text ) = $this->_flatten( $options | $WC::NO_BLOCK_TML );
        my $p = _htmlParams( $this->{attrs}, $options );
        $text =~ s/<br( \/)?>/$WC::NBBR/g;
        return ($WC::BLOCK_TML, "$WC::CHECKn<pre$p>$WC::CHECKn".$text.
                "$WC::CHECKn</pre>$WC::CHECKn");
    }
    return ( 0, undef );
}

sub _handleQ    { return _flatten( @_ ); };
# S
sub _handleSAMP { return _handleTT( @_ ); };
# SCRIPT
# SELECT
# SMALL

sub _handleSPAN {
    my( $this, $options ) = @_;
    if( defined( $this->{attrs}->{class} )) {
        if( $this->{attrs}->{class} =~ /\bTMLvariable\b/ ) {
            my( $flags, $text ) = $this->_flatten(
                $options | $WC::NO_BLOCK_TML );
            my $var = _trim($text);
            my $nop = ($options & $WC::NOP_ALL) ? '<nop>' : '';
            # don't create unnamed variables
            $var = '%'.$nop.$var.'%' if( $var );
            return (0, $var);
        }

        if( $this->{attrs}->{class} =~ /\bTMLcomment\b/ ) {
            my( $flags, $text ) = $this->_flatten(
                $options | $WC::NO_BLOCK_TML );
            return (0, '<!--'.$text.'-->' );
        }

        if( $this->{attrs}->{class} =~ /\bTMLnop\b/) {
            my( $flags, $kids ) = $this->_flatten(
                $options | $WC::NOP_ALL );
            $kids =~ s/%([A-Z0-9_:]+({.*})?)%/%<nop>$1%/g;
            return ( $flags, $kids );
        }

        if( $this->{attrs}->{class} =~ /\bTMLnopresult\b/) {
            my( $flags, $kids ) = $this->_flatten( $options );
            return ( $flags, '<nop>'.$kids );
        }

        delete $this->{attrs}->{class};
    }

    # ignore the span if there are no attrs
    if( !scalar( %{$this->{attrs}}) ) {
        return $this->_flatten( $options );
    }

    return (0, undef);
}

# STRIKE

sub _handleSTRONG {
    my( $this, $options ) = @_;
    if( scalar( @{$this->{children}} ) == 1 ) {
        if( $this->{children}->[0]->{tag} =~ /^(i|em)$/i ) {
            return _emphasis( $this->{children}->[0], $options, '__' );
        } elsif( $this->{children}->[0]->{tag} =~ /^(code|tt)$/i ) {
            return _emphasis( $this->{children}->[0], $options, '==' );
        }
    }
    return _emphasis( @_, '*' );
}

sub _handleSTYLE { return ( 0, '' ); }
# SUB
# SUP

sub _handleTABLE {
    my( $this, $options ) = @_;
    return ( 0, undef) if( $options & $WC::NO_BLOCK_TML );

    # Should really look at the table attrs, but to heck with it

    return ( 0, undef ) if( $options & $WC::NO_BLOCK_TML );

    my @table;
    return ( 0, undef ) unless
      $this->_isConvertableTable( $options | $WC::NO_BLOCK_TML, \@table );

    my $maxrow = 0;
    my $row;
    foreach $row ( @table ) {
        my $rw = scalar( @$row );
        $maxrow = $rw if( $rw > $maxrow );
    }
    foreach $row ( @table ) {
        while( scalar( @$row ) < $maxrow) {
            push( @$row, '' );
        }
    }
    my $text = $WC::CHECKn;
    foreach $row ( @table ) {
        # isConvertableTableRow has already formatted the cell
        $text .= $WC::CHECKn.'|'.join('|', @$row).'|'.$WC::CHECKn;
    }

    return ( $WC::BLOCK_TML, $text );
}

sub _handleTBODY { return _flatten( @_ ); }
sub _handleTD { return _flatten( @_ ); }

sub _handleTEXTAREA {
    my( $this, $options ) = @_;
    if( $this->{attrs}->{class} &&
        $this->{attrs}->{class} =~ /\bTMLcomment\b/ ) {
        my( $flags, $text ) = $this->_flatten( $options | $WC::NO_BLOCK_TML );
        return (0, "<!--\n".$text."\n-->" );
    }

    if( $options & $WC::VERY_CLEAN ) {
        return $this->_flatten( $options );
    }
    return (0, undef);
}

sub _handleTFOOT { return _flatten( @_ ); }
sub _handleTH    { return _flatten( @_ ); }
sub _handleTHEAD { return _flatten( @_ ); }
sub _handleTITLE { return (0, '' ); }
sub _handleTR    { return _flatten( @_ ); }
sub _handleTT    { return _handleCODE( @_ ); }
# U
sub _handleUL    { return _LIST( @_ ); }
sub _handleVAR   { return ( 0, '' ); }

1;
