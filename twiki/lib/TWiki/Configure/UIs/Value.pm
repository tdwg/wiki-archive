#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
#
# UI generating package for simple values
#
use strict;

package TWiki::Configure::UIs::Value;

use base 'TWiki::Configure::UI';

# Generates the appropriate HTML for getting a value to configure the
# entry. The actual input field is decided by the type.
sub open_html {
    my ($this, $value, $valuer) = @_;

    my $type = $value->getType();
    return '' if $value->{hidden};

    my $trclass = '';
    my $info = '';
    if ($value->{opts} =~ /(\b|^)EXPERT(\b|$)/i) {
        $info = CGI::h6('EXPERT') . $info;
        $trclass = 'expertsOnly';
    }
    $info .= $value->{desc};
    my $keys = $value->getKeys();
    my $checker = TWiki::Configure::UI::loadChecker($keys, $value);
    # SMELL the following line is reported to have
    #       Use of uninitialized value in concatenation (.) or string
    #       under some circumstances.  Should check routines return undef?
    $info .= $checker->check($value) || '' if $checker;

    my $class = $value->{typename};
    $class .= ' mandatory' if ($value->{mandatory});
    my $prompter = $type->prompt(
       $keys, $value->{opts}, $valuer->currentValue($value));
    $prompter = CGI::span({class=>$class}, $prompter);

	my $hiddenText = $this->hidden( 'TYPEOF:'.$keys, $value->{typename} );
	my $cssClass = 'docdata info';
	# Hide row if the hidden input field is the only contents
	$cssClass .= ' twikiHidden' if $info eq '';
    my $td = CGI::td(
        { colspan => 2, class=>$cssClass },
        $hiddenText.$info );
    my $row1;
    
    
    if ($value->{hidden}) {
    	# This seems never to happen
        $row1 = CGI::Tr({class => 'hiddenRow '.$trclass }, $td)."\n";
    } else {
        $row1 = CGI::Tr({ class => $trclass }, $td)."\n";
    }

    $keys = CGI::span({class=>'mandatory'}, $keys) if $value->{mandatory};

    my $row2col1 = $keys;
    if ($value->needsSaving($valuer)) {
        my $v = $valuer->defaultValue($value) || '';
        $row2col1 .= CGI::span({title => 'default = '.$v,
                                class => 'twikiAlert'}, '&delta;');
    }

    return $row1.
      CGI::Tr( { class => $trclass },
          CGI::td({class=>'firstCol'}, $row2col1)."\n".
              CGI::td({class=>'secondCol'}, $prompter))."\n";
}

sub close_html {
    my $this = shift;
    return '';
}

1;
