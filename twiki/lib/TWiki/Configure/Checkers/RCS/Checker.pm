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
use strict;

package TWiki::Configure::Checkers::RCS::Checker;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

my $rcsverRequired = 5.7;

sub checkRCSProgram {
    my ($this, $key) = @_;

    return 'Not used in this configuration.'
      unless $TWiki::cfg{StoreImpl} eq 'RcsWrap';

    my $mess = '';
    my $err = '';
    my $prog = $TWiki::cfg{RCS}{$key} || '';
    $prog =~ s/^\s*(\S+)\s.*$/$1/;
    $prog =~ /^(.*)$/; $prog = $1;
    if( !$prog ) {
        $err .= $key.' is not set';
    } else {
        my $version = `$prog -V` || '';
        if( $@ ) {
            $err .= $this->ERROR($prog.' returned an error: '.$@ );
        } elsif ( $version ne '' ) {
            $version =~ /(\d+(\.\d+)+)/;
            $version = $1;
            $mess .= " ($prog is version $version)";
        } else {
            $err .= $this->ERROR($prog.' did not return a version number (or might not exist..)');
        }
        if( $version && $version < $rcsverRequired ) {
            # RCS too old
            $err .= $prog.' is too old, upgrade to version '.
              $rcsverRequired.' or higher.';
        }
    }
    if( $err ) {
        $mess .= $this->ERROR( $err .<<HERE
TWiki will probably not work with this RCS setup. Either correct the setup, or
switch to RcsLite. To enable RCSLite you need to change the setting of
{StoreImpl} to 'RcsLite'.
HERE
                       );
    }
    return $mess;
}

1;
