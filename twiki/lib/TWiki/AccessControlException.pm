# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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

=pod twiki

---+ package TWiki::AccessControlException

Exception used raise an access control violation.

=cut

package TWiki::AccessControlException;

use strict;
use Error;

@TWiki::AccessControlException::ISA = qw(Error);

=pod

---+ ClassMethod new($mode, $user, $web, $topic, $reason)

   * =$mode= - mode of access (view, change etc)
   * =$user= - user object doing the accessing
   * =$web= - web being accessed
   * =$topic= - topic being accessed
   * =$reason= - string reason for failure

All the above fields are accessible from the object in a catch clause
in the usual way e.g. =$e->{web}= and =$e->{reason}=

=cut

sub new {
    my ( $class, $mode, $user, $web, $topic, $reason ) = @_;

    return $class->SUPER::new(
                              web => $web,
                              topic => $topic,
                              user => $user->wikiName(),
                              mode => $mode,
                              reason => $reason,
                             );
}

=pod

---++ ObjectMethod stringify() -> $string

Generate a summary string

=cut

sub stringify {
    my $this = shift;
    return "AccessControlException: Access to $this->{mode} $this->{web}.$this->{topic} for $this->{user} is denied. $this->{reason}";
}

1;
