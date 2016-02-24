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

=pod

---+ package WC

Constants, and base class of Node and Leaf

_generate
_cleanAttrs
addChild
stringify

=cut

package WC;

=pod

---++ Generator flags
| $NO_TML | Flag that gets passed _down_ into generator functions. Constrains output to HTML only. |
| $NO_BLOCK_TML | Flag that gets passed _down_ into generator functions. Don't generate block TML e.g. tables, lists |
| $NOP_ALL | Flag that gets passed _down_ into generator functions. NOP all variables and WikiWords. |
| $BLOCK_TML | Flag passed up from generator functions; set if expansion includes block TML |
| $VERY_CLEAN | Flag passed to indicate that HTML must be aggressively cleaned (unrecognised or unuseful tags stripped out) |

=cut

use vars qw( $NO_TML $NO_BLOCK_TML $NOP_ALL $BLOCK_TML );

$NO_HTML      = 1 << 0;
$NO_TML       = 1 << 1;
$NO_BLOCK_TML = 1 << 2;
$NOP_ALL      = 1 << 3;
$VERY_CLEAN   = 1 << 4;

$BLOCK_TML    = $NO_BLOCK_TML;

=pod

---++ Assertions
The generator works by expanding to "decorated" text, where the decorators
are non-printable characters. These characters act express format
requirements - for example, the need to have a newline before some text,
or the need for a space. Whitespace is collapsed down to the minimum that
satisfies the format requirements.

| $CHECKn | Marker that gets inserted in text in spaces where there must be an adjacent newline |
| $CHECKs | Marker that gets inserted in text in spaces where there must be a adjacent whitespace |
| $NBSP | Non-breaking space, never gets deleted |
| $NBBR | Non-breaking linebreak; never gets deleted |

=cut

use vars qw( $CHECKn $CHECKw $CHECKs $NBSP $NBBR );
$CHECKn = "\001"; # require adjacent newline (\n or $NBBR)
$CHECKs = "\002"; # require adjacent space character (' ' or $NBSP)
$CHECKw = "\003"; # require adjacent whitespace (\s|$NBBR|$NBSP)
$NBSP   = "\004"; # unbreakable space
$NBBR   = "\005"; # unbreakable newline
$CHECK1 = "\006"; # start of wiki-word
$CHECK2 = "\007"; # end of wiki-word

=pod

---++ REs
REs for matching delimiters of wikiwords
must be consistent with TML2HTML.pm (and Render.pm of course)

| $STARTWW | Zero-width match for the start of a wikiword |
| $ENDWW | Zero-width match for the end of a wikiword |
| $PROTOCOL | match for a valid URL protocol e.g. http, mailto etc |

=cut

use vars qw( $STARTWW $ENDWW $PROTOCOL );

$STARTWW = qr/^|(?<=[ \t\n\(\!])/om;
$ENDWW = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])/om;
$PROTOCOL = qr/^(file|ftp|gopher|http|https|irc|news|nntp|telnet|mailto):/;

# Table of HTML tags that says whether they should have a newline before
# them when they are encountered in a preformatted (verbatim) block. This
# supports very crude formatting during removal of HTML tags.
use vars qw( %BREAK_BEFORE );

%BREAK_BEFORE = (
    A => 0,
    ABBR => 0,
    ACRONYM => 0,
    ADDRESS => 0,
    APPLET => 1,
    AREA => 0,
    B => 0,
    BASE => 0,
    BASEFONT => 0,
    BDO => 0,
    BIG => 0,
    BLOCKQUOTE => 1,
    BODY => 1,
    BR => 1,
    BUTTON => 0,
    CAPTION => 0,
    CENTER => 1,
    CITE => 0,
    CODE => 0,
    COL => 0,
    COLGROUP => 0,
    DD => 0,
    DEL => 0,
    DFN => 0,
    DIR => 1,
    DIV => 1,
    DL => 1,
    DT => 1,
    EM => 0,
    FIELDSET => 1,
    FONT => 0,
    FORM => 1,
    FRAME => 1,
    FRAMESET => 1,
    H1 => 1,
    H2 => 1,
    H3 => 1,
    H4 => 1,
    H5 => 1,
    H6 => 1,
    HEAD => 1,
    HR => 1,
    HTML => 1,
    I => 0,
    IFRAME => 0,
    IMG => 0,
    INPUT => 0,
    INS => 0,
    ISINDEX => 1,
    KBD => 0,
    LABEL => 0,
    LEGEND => 1,
    LI => 1,
    LINK => 1,
    MAP => 1,
    MENU => 1,
    META => 1,
    NOFRAMES => 0,
    NOSCRIPT => 1,
    OBJECT => 1,
    OL => 1,
    OPTGROUP => 0,
    OPTION => 0,
    P => 1,
    PARAM => 1,
    PRE => 1,
    Q => 0,
    S => 0,
    SAMP => 0,
    SCRIPT => 1,
    SELECT => 0,
    SMALL => 0,
    SPAN => 0,
    STRIKE => 0,
    STRONG => 0,
    STYLE => 1,
    SUB => 0,
    SUP => 0,
    TABLE => 1,
    TBODY => 1,
    TD => 0,
    TEXTAREA => 1,
    TFOOT => 1,
    TH => 0,
    THEAD => 1,
    TITLE => 1,
    TR => 1,
    TT => 0,
    U => 0,
    UL => 1,
    VAR => 0,
   );

# pure virtual
sub generate {
    die "coding error";
}

# pure virtual
sub addChild {
    die "coding error";
}

sub cleanNode {
}

sub cleanParseTree {
    my( $this, $opts ) = @_;

    $this->cleanNode($opts);

    # thread siblings and parents
    my $prev;
    foreach my $kid (@{$this->{children}}) {
        $kid->{parent} = $this;
        $kid->{prev} = $prev;
        $prev->{next} = $kid if $prev;
        $kid->cleanParseTree($opts);
        $prev = $kid;
    }
}

sub stringify {
    return '';
}

1;
