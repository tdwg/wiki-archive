# Copyright (C) 2005 ILOG http://www.ilog.fr
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

---+ package TWiki::Plugins::WysiwygPlugin::TML2HTML

Convertor class for translating TML (TWiki Meta Language) into
HTML

The convertor does _not_ use the TWiki rendering, as that is a
lossy conversion, and would make symmetric translation back to TML
an impossibility.

The design goal was to support round-trip conversion from well-formed
TML to XHTML1.0 and back to identical TML. Notes that some deprecated
TML syntax is not supported.

=cut

package TWiki::Plugins::WysiwygPlugin::TML2HTML;

use strict;
use TWiki;
use CGI qw( -any );
use HTML::Entities;

my $TT0 = chr(0);
my $TT1 = chr(1);
my $TT2 = chr(2);

my $STARTWW = qr/^|(?<=[\s\(])/m;
my $ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

=pod

---++ ClassMethod new()

Construct a new TML to HTML convertor.

=cut

sub new {
    my $class = shift;
    my $this = {};
    return bless( $this, $class );
}

=pod

---++ ObjectMethod convert( $tml, \%options ) -> $tml

Convert a block of TML text into HTML.
Options:
   * getViewUrl is a reference to a method:<br>
     getViewUrl($web,$topic) -> $url (where $topic may include an anchor)
   * markVars is true if we are to expand TWiki variables to spans.
     It should be false otherwise (TWiki variables will be left as text).

=cut

sub convert {
    my( $this, $content, $options ) = @_;

    $this->{opts} = $options;

    return '' unless $content;

    $content =~ s/\\\n/ /g;

    $content =~ s/[$TT0$TT1]/!/go;	

    # Render TML constructs to tagged HTML
    $content = $this->_getRenderedVersion( $content );

    # Substitute back in protected elements
    $content = $this->_dropBack( $content );

    # This should really use a template, but what the heck...
    return $content;
}

sub _liftOut {
    my( $this, $text ) = @_;
    my $n = scalar( @{$this->{refs}} );
    push( @{$this->{refs}}, $text );
    return $TT1.$n.$TT1;
}

sub _dropBack {
    my( $this, $text) = @_;
    # Restore everything that was lifted out
    while( $text =~ s/$TT1([0-9]+)$TT1/$this->{refs}->[$1]/gi ) {
    }
    return $text;
}

# Parse and convert twiki variables. If we are not using span markers
# for variables, we have to change the percent signs into entities
# to prevent internal tags being expanded by TWiki during rendering.
# It's assumed that the editor will have the common sense to convert
# them back to characters when editing.
sub _processTags {
    my( $this, $text ) = @_;

    return '' unless defined( $text );

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = '';

    while( scalar( @queue )) {
        my $token = shift( @queue );
        if( $token eq '%' ) {
            if( $stackTop =~ /}$/ ) {
                while( scalar( @stack) &&
                         $stackTop !~ /^%(<nop(result| *\/)?>)?([A-Z0-9_:]+){.*}$/o ) {
                    $stackTop = pop( @stack ) . $stackTop;
                }
            }
            if( $stackTop =~ m/^%(<nop(?:result| *\/)?>)?([A-Z0-9_:]+)({.*})?$/o ) {
                my $nop = $1 || '';
                my $tag = $2 . ( $3 || '' );
                $tag = '%'.$tag.'%';
                if( $nop ) {
                    $nop =~ s/[<>]//g;
                    $tag = CGI::span( { class=>'TML'.$nop }, $tag );
                }
                $stackTop = pop( @stack ).$this->_liftOut( $tag );
            } else {
                push( @stack, $stackTop );
                $stackTop = '%'; # push a new context
            }
        } else {
            $stackTop .= $token;
        }
    }
    # Run out of input. Gather up everything in the stack.
    while ( scalar( @stack )) {
        $stackTop = pop( @stack ).$stackTop;
    }

    return $stackTop;
}

sub _makeLink {
    my( $this, $url, $text ) = @_;
    $text ||= $url;
    $url = $this->_liftOut($url);
    return CGI::a( { href => $url }, $text );
}

sub _makeWikiWord {
    my( $this, $text, $web, $topic, $anchor ) = @_;
    my $url = &{$this->{opts}->{getViewUrl}}( $web, $topic );
    $url .= $anchor if $anchor;
    return $this->_makeLink( $url, $text );
}

sub _expandRef {
    my( $this, $ref ) = @_;
    if( $this->{opts}->{expandVarsInURL} ) {
        my $origtxt = $this->{refs}->[$ref];
        my $newtxt =
          &{$this->{opts}->{expandVarsInURL}}( $origtxt, $this->{opts} );
        return $newtxt if $newtxt ne $origtxt;
    }
    return "$TT1$ref$TT1";
}

sub _expandURL {
    my( $this, $url ) = @_;
    return $url unless ( $this->{opts}->{expandVarsInURL} );
    return &{$this->{opts}->{expandVarsInURL}}( $url, $this->{opts} );
}

sub _makeSquab {
    my( $this, $url, $text ) = @_;

    my $save = $url;
    $url =~ s/$TT1([0-9]+)$TT1/$this->_expandRef($1)/ge;
    if( $url =~ /[<>"\x00-\x1f]/ ) {
        # we didn't manage to expand some variables in the url
        # path. Give up.
        # If we can't completely expand the URL, then don't expand
        # *any* of it (hence $save)
        return defined($text) ? "[[$save][$text]]" : "[[$save]]";
    }

    unless( $text ) {
        # forced link [[Word]] or [[url]]
        $text = $url;
        if( $url !~ /^($TWiki::regex{linkProtocolPattern}:|\/)/ ) {
            my $wurl = $url;
            $wurl =~ s/(^| )(.)/\U$2/g;
            if( $wurl =~ /^(?:($TWiki::regex{webNameRegex})\.)?(.*)$/ ) {
                $url = &{$this->{opts}->{getViewUrl}}( $1, $2 );
            } else {
                $url = &{$this->{opts}->{getViewUrl}}( undef, $wurl );
            }
        }
    } elsif ($url =~ /^(?:($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex})($TWiki::regex{anchorRegex})?$/) {
        # Valid wikiword expression
        my $a = $3 || '';
        $url = &{$this->{opts}->{getViewUrl}}( $1, $2 ) . $a;
    }

    $text =~ s/(?<=[\s\(])((?:($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}))/<nop>$1/gom;

    return $this->_makeLink($url, $text);
}

# Lifted straight out of DevelopBranch Render.pm
sub _getRenderedVersion {
    my( $this, $text, $refs ) = @_;

    return '' unless $text;  # nothing to do

    @{$this->{LIST}} = ();
    $this->{refs} = [];

    # Initial cleanup
    $text =~ s/\r//g;
    $text =~ s/^\n*//s;
    $text =~ s/\n*$//s;

    my $removed = {}; # Map of placeholders to tag parameters and text
    $text = _takeOutBlocks( $text, 'verbatim', $removed );

    # Remove PRE to prevent TML interpretation of text inside it
    $text = _takeOutBlocks( $text, 'pre', $removed );

    # change !%XXX to %<nop>XXX
    $text =~ s/!%(?=[A-Z]+({|%))/%<nop>/g;

    # change <nop>%XXX to %<nopresult>XXX. A nop before th % indicates
    # that the result of the tag expansion is to be nopped
    $text =~ s/<nop>%(?=[A-Z]+({|%))/%<nopresult>/g;

    # Pull comments
    $text =~ s/(<!--.*?-->)/$this->_liftOut($1)/ges;

    # Remove TML pseudo-tags so they don't get protected like HTML tags
    $text =~ s/<(.?(noautolink|nop|nopresult).*?)>/$TT1($1)$TT1/gi;

    # Expand selected TWiki variables in IMG tags so that images appear in the
    # editor as images
    $text =~ s/(<img [^>]*src=)(["'])(.*?)\2/$1.$2.$this->_expandURL($3).$2/gie;
    # protect HTML tags by pulling them out
    $text =~ s/(<\/?[a-z]+(\s[^>]*)?>)/ $this->_liftOut($1) /gei;

    # Replace TML pseudo-tags
    $text =~ s/$TT1\((.*?)\)$TT1/<$1>/go;

    # Convert TWiki tags to spans outside parameters
    $text = $this->_processTags( $text );

    # Change ' !AnyWord' to ' <nop>AnyWord',
    $text =~ s/$STARTWW!(?=[\w\*\=])/<nop>/gm;

    $text =~ s/\\\n//gs;  # Join lines ending in '\'

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~ s/^>(.*?)$/'&gt;'.CGI::cite( { class => 'TMLcite' }, $1 ).CGI::br()/gem;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$TT0!--/g;
    $text =~ s/-->/--}$TT0/g;
    # SMELL: this next fragment is a frightful hack, to handle the
    # case where simple HTML tags (i.e. without values) are embedded
    # in the values provided to other tags. The only way to do this
    # correctly (i.e. handle HTML tags with values as well) is to
    # parse the HTML (bleagh!)
    $text =~ s/<(\/[A-Za-z]+)>/{$TT0$1}$TT0/g;
    $text =~ s/<([A-Za-z]+(\s+\/)?)>/{$TT0$1}$TT0/g;
    $text =~ s/<(\S.*?)>/{$TT0$1}$TT0/g;
    # entitify lone < and >, praying that we haven't screwed up :-(
    $text =~ s/</&lt\;/g;
    $text =~ s/>/&gt\;/g;
    $text =~ s/{$TT0/</go;
    $text =~ s/}$TT0/>/go;

    # standard URI
    $text =~ s/(?:^|(?<=[-*\s(]))($TWiki::regex{linkProtocolPattern}:([^\s<>"]+[^\s*.,!?;:)<]))/$this->_makeLink($1,$1)/geo;

    # other entities
    $text =~ s/&(\w+);/$TT0$1;/g;      # "&abc;"
    $text =~ s/&(#[0-9]+);/$TT0$1;/g;  # "&#123;"
    #$text =~ s/&/&amp;/g;                         # escape standalone "&"
    $text =~ s/$TT0(#[0-9]+;)/&$1/go;
    $text =~ s/$TT0(\w+;)/&$1/go;

    # Headings
    # '----+++++++' rule
    $text =~ s/$TWiki::regex{headerPatternDa}/_makeHeading($2,length($1))/geom;

    # Horizontal rule
    my $hr = CGI::hr({class => 'TMLhr'});
    $text =~ s/^---+/$hr/gm;

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $isList = 0;		# True when within a list
    my $insideTABLE = 0;
    my @result = ();
    foreach my $line ( split( /\n/, $text )) {
        # Table: | cell | cell |
        # allow trailing white space after the last |
        if( $line =~ m/^(\s*\|.*\|\s*)$/ ) {
            unless( $insideTABLE ) {
                push( @result, CGI::start_table(
                    { border=>1, cellpadding=>0, cellspacing=>1 } ));
            }
            push( @result, _emitTR($1) );
            $insideTABLE = 1;
            next;
        } elsif( $insideTABLE ) {
            push( @result, CGI::end_table() );
            $insideTABLE = 0;
        }

        # Lists and paragraphs
        if ( $line =~ s/^\s*$/<p \/>/o ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\S+?)/o ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\t|   )+\S/ ) {
            if ( $line =~ s/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $3 <\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)\* /<li> /o ) {
                # Unnumbered list
                $this->_addListItem( \@result, 'ul', 'li', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {
                # Numbered list
                my $ot = $3;
                $ot =~ s/^(.).*/$1/;
                if( $ot !~ /^\d$/ ) {
                    $ot = ' type="'.$ot.'"';
                } else {
                    $ot = '';
                }
                $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
                $this->_addListItem( \@result, 'ol', 'li', $1, $ot );
                $isList = 1;
            }
        } else {
            $isList = 0;
        }

        # Finish the list
        if( ! $isList ) {
            $this->_addListItem( \@result, '', '', '' );
            $isList = 0;
        }

        push( @result, $line );
    }

    if( $insideTABLE ) {
        push( @result, '</table>' );
    }
    $this->_addListItem( \@result, '', '', '' );

    $text = join("\n", @result );

    $text =~ s(${STARTWW}==([^\s]+?|[^\s].*?[^\s])==$ENDWW)
      (CGI::b(CGI::code($1)))gem;
    $text =~ s(${STARTWW}__([^\s]+?|[^\s].*?[^\s])__$ENDWW)
      (CGI::b(CGI::i($1)))gem;
    $text =~ s(${STARTWW}\*([^\s]+?|[^\s].*?[^\s])\*$ENDWW)
      (CGI::b($1))gem;
    $text =~ s(${STARTWW}\_([^\s]+?|[^\s].*?[^\s])\_$ENDWW)
      (CGI::i($1))gem;
    $text =~ s(${STARTWW}\=([^\s]+?|[^\s].*?[^\s])\=$ENDWW)
      (CGI::code($1))gem;

    # Handle [[][] and [[]] links

    # Escape rendering: Change ' ![[...' to ' [<nop>[...', for final unrendered ' [[...' output
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;

    # We _not_ support [[http://link text]] syntax

    # detect and escape nopped [[][]]
    $text =~ s(\[<nop(?: *\/)?>(\[.*?\](?:\[.*?\])?)\])
      ([<span class="TMLnop">$1</span>])g;
    $text =~ s(!\[(\[.*?\])(\[.*?\])?\])
      ([<span class="TMLnop">$1$2</span>])g;

    # Spaced-out Wiki words with alternative link text
    # i.e. [[$1][$3]]

    $text =~ s/\[\[([^\]]*)\](?:\[([^\]]+)\])?\]/$this->_makeSquab($1,$2)/ge;

    # Handle WikiWords
    $text = _takeOutBlocks( $text, 'noautolink', $removed );

    $text =~ s#<nop(?: */)?>($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex})#<span class="TMLnop">$1</span>#gom;

    $text =~ s/$STARTWW((?:($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex})($TWiki::regex{anchorRegex})?)/$this->_makeWikiWord($1,$2,$3,$4)/geom;
    foreach my $placeholder ( keys %$removed ) {
        my $pm = $removed->{$placeholder}{params}->{class};
        if( $placeholder =~ /^noautolink/i ) {
            if( $pm ) {
                $pm = join(' ', ( split( /\s+/, $pm ), 'TMLnoautolink' ));
            } else {
                $pm = 'TMLnoautolink';
            }
            $removed->{$placeholder}{params}->{class} = $pm;
        } elsif( $placeholder =~ /^verbatim/i ) {
            if( $pm ) {
                $pm = join(' ', ( split( /\s+/, $pm ), 'TMLverbatim' ));
            } else {
                $pm = 'TMLverbatim';
            }
            $removed->{$placeholder}{params}->{class} = $pm;
        }
    }

    _putBackBlocks( $text, $removed, 'noautolink', 'div' );

    _putBackBlocks( $text, $removed, 'pre' );

    # replace verbatim with pre in the final output
    _putBackBlocks( $text, $removed, 'verbatim', 'pre',
                    \&_encodeEntities );

    # There shouldn't be any lingering <nopresult>s, but just
    # in case there are, convert them to <nop>s so they get removed.
    $text =~ s/<nopresult>/<nop>/g;

    return $text;
}

sub _encodeEntities {
    my $text = shift;

    return HTML::Entities::encode_entities( $text );
}

# Make the html for a heading
sub _makeHeading {
    my( $theHeading, $theLevel ) = @_;
    my $class = 'TML';
    if( $theHeading =~ s/$TWiki::regex{headerPatternNoTOC}//o ) {
        $class .= ' notoc';
    }
    my $attrs = { class => $class };
    my $fn = 'CGI::h'.$theLevel;
    no strict 'refs';
    return &$fn($attrs, " $theHeading ");
    use strict 'refs';
}

# Lifted straight out of DevelopBranch Render.pm
sub _takeOutBlocks {
    my( $intext, $tag, $map ) = @_;
    die unless $tag;
    return '' unless $intext;
    return $intext unless ( $intext =~ m/<$tag\b/ );

    my $open = qr/^(.*)<$tag\b([^>]*)>(.*)$/i;
    my $close = qr/^(.*)<\/$tag>(.*)$/i;
    my $out = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;
    my $n = 0;

    foreach my $line ( split/\r?\n/, $intext ) {
        if( $line =~ m/$open/ ) {
            unless( $depth++ ) {
                $out .= $1;
                $tagParams = $2;
                $scoop = '';
                $line = $3;
            }
        }
        if( $depth && $line =~ m/$close/ ) {
            $scoop .= $1;
            my $rest = $2;
            unless ( --$depth ) {
                my $placeholder = $tag.$n;
                $map->{$placeholder}{params} = _parseParams( $tagParams );
                $map->{$placeholder}{text} = $scoop;

                $line = $TT0.$placeholder.$TT0;
                $n++;
            }
        }
        if ( $depth ) {
            $scoop .= $line."\n";
        } else {
            $out .= $line."\n";
        }
    }

    if ( $depth ) {
        # This would generate matching close tags
        # while ( $depth-- ) {
        #     $scoop .= "</$tag>\n";
        # }
        my $placeholder = $tag.$n;
        $map->{$placeholder}{params} = _parseParams( $tagParams );
        $map->{$placeholder}{text} = $scoop;
        $out .= $TT0.$placeholder.$TT0;
    }

    return $out;
}

# Lifted straight out of DevelopBranch Render.pm
sub _putBackBlocks {
    my( $text, $map, $tag, $newtag, $callback ) = @_;
    my $fn = 'CGI::'.($newtag || $tag);
    $newtag ||= $tag;
    my @k = keys %$map;
    foreach my $placeholder ( @k ) {
        if( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params};
            my $val = $map->{$placeholder}{text};
            $val = &$callback( $val ) if ( defined( $callback ));
            no strict 'refs';
            $_[0] =~ s/$TT0$placeholder$TT0/&$fn($params,$val)/e;
            use strict 'refs';
            delete( $map->{$placeholder} );
        }
    }
}

sub _parseParams {
    my $p = shift;
    my $params = {};
    while( $p =~ s/^\s*(\w+)=(".*?"|'.*?')// ) {
        my $name = $1;
        my $val = $2;
        $val =~ s/['"](.*)['"]/$1/;
        $params->{$name} = $val;
    }
    return $params;
}

# Lifted straight out of DevelopBranch Render.pm
sub _addListItem {
    my( $this, $result, $theType, $theElement, $theIndent, $theOlType ) = @_;

    $theIndent =~ s/   /\t/g;
    my $depth = length( $theIndent );

    my $size = scalar( @{$this->{LIST}} );
    if( $size < $depth ) {
        my $firstTime = 1;
        while( $size < $depth ) {
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
            push( @$result, "<$theElement>" ) unless( $firstTime );
            push( @$result, "<$theType>" );
            $firstTime = 0;
            $size++;
        }
    } else {
        while( $size > $depth ) {
            my $tags = pop( @{$this->{LIST}} );
            push( @$result, "</$tags->{element}>" );
            push( @$result, "</$tags->{type}>" );
            $size--;
        }
        if ($size) {
            push( @$result, "</$this->{LIST}->[$size-1]->{element}>" );
        }
    }

    if ( $size ) {
        my $oldt = $this->{LIST}->[$size-1];
        if( $oldt->{type} ne $theType ) {
            push( @$result, "</$oldt->{type}>\n<$theType>" );
            pop( @{$this->{LIST}} );
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
        }
    }
}

sub _emitTR {
    my $row = shift;

    $row =~ s/\t/   /g;  # change tabs to space
    $row =~ s/^(\s*)\|//;
    my $pre = $1;

    my @tr;

    while( $row =~ s/^(.*?)\|// ) {
        my $cell = $1;

        if( $cell eq '' ) {
            $cell = '%SPAN%';
        }

        my $attr = {};

        my( $left, $right ) = ( 0, 0 );
        if( $cell =~ /^(\s*).*?(\s*)$/ ) {
            $left = length( $1 );
            $right = length( $2 );
        }

        if( $left > $right ) {
            $attr->{class} = 'align-right';
            $attr->{style} = 'text-align: right';
        } elsif( $left < $right ) {
            $attr->{class} = 'align-left';
            $attr->{style} = 'text-align: left';
        } elsif( $left > 1 ) {
            $attr->{class} = 'align-center';
            $attr->{style} = 'text-align: center';
        }

        # make sure there's something there in empty cells. Otherwise
        # the editor will compress it to (visual) nothing.
        $cell =~ s/^\s*$/&nbsp;/g;

        # Removed TH to avoid problems with handling table headers. TWiki
        # allows TH anywhere, but editors assume top row only, mostly.
        # See Item1185
        push( @tr, CGI::td( $attr, $cell ));
    }
    return $pre.CGI::Tr( join( '', @tr));
}

1;
