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

---+ package TWiki::Plugins::WysiwygPlugin::TML2HTML::Leaf

Object for a leaf node in an HTML parse tree

A leaf node is text in the document.

See also TWiki::Plugins::WysiwygPlugin::TML2HTML::Node

=cut

package TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;

use strict;

use TWiki::Plugins::WysiwygPlugin::HTML2TML::WC;
@TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf::ISA = qw( WC );

sub new {
    my( $class, $text ) = @_;

    my $this = {};

    $this->{tag} = '';
    $this->{text} = $text;
    return bless( $this, $class );
}

sub generate {
    my( $this, $options ) = @_;
    my $t = $this->{text};
    $t =~ s/\n/$WC::CHECKn/g;
    if( $options & $WC::NOP_ALL ) {
        # escape all embedded wikiwords
        $t =~ s/$WC::STARTWW($TWiki::regex{wikiWordRegex})/<nop>$1/go;
        $t =~ s/$WC::STARTWW($TWiki::regex{abbrevRegex})/<nop>$1/go;
        $t =~ s/\[/<nop>[/g;
    }
    return (0, $t);
}

sub stringify {
    my $this = shift;
    return $this->{text};
}

1;
