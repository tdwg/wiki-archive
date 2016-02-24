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
use strict;

package TWiki::Configure::UIs::PLUGINS;

use TWiki::Configure::UIs::Section;

use base 'TWiki::Configure::UIs::Section';

sub close_html {
    my ($this, $section) = @_;

    my $button = <<HERE;
Click here to consult the online plugins repository for
new plugins. <b>Warning:</b>Unsaved changes will be lost!
HERE
    # Check that the extensions UI is loadable
    my $bad = 0;
    foreach my $module qw(TWiki::Configure::UIs::EXTEND TWiki::Configure::UIs::EXTENSIONS) {
        eval "use $module";
        if ($@) {
            $bad = 1;
            last;
        }
    }
    my $actor;
    if (!$bad) {
        # Can't use a submit here, because if we do, it is invoked when
        # the user presses Enter in a text field.
        my $scriptName = $ENV{SCRIPT_NAME} || 'THISSCRIPT';
        $actor = CGI::a({ href => $scriptName.'?action=FindMoreExtensions',
                          class=>'twikiSubmit',
                          accesskey => 'P' },
                        'Find More Extensions');
    } else {
        $actor = $this->WARN(<<MESSAGE);
Cannot load the extensions installer.
Check 'Perl Modules' in the 'CGI Setup' section above, and install any
missing modules required for the Extensions Installer.
MESSAGE
    }
    return CGI::Tr(CGI::td($button),CGI::td($actor)).
      $this->SUPER::close_html($section);
}

1;
