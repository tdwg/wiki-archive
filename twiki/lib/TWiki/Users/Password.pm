# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
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

=begin twiki

---+ package TWiki::Users::Password

Base class of all password handlers. Default behaviour is no passwords,
so anyone can be anyone they like.

The methods of this class should be overridded by subclasses that want
to implement other password handling methods.

=cut

package TWiki::Users::Password;

use strict;

=pod

---++ ClassMethod new( $session ) -> $object

Constructs a new password handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( {}, $class );
    $this->{session} = $session;
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

=pod

---++ ObjectMethod fetchPass( $login ) -> $passwordE

Implements TWiki::Password

Returns encrypted password if succeeds.  Returns 0 if login is invalid.
Returns undef otherwise.

=cut

sub fetchPass {
    return '';
}

=pod

---++ ObjectMethod checkPassword( $user, $passwordU ) -> $boolean

Finds if the password is valid for the given login.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    return 1;
}

=pod

---++ ObjectMethod deleteUser( $user ) -> $boolean

Delete users entry.

Returns 1 on success, undef on failure.

=cut

sub deleteUser {
    return 1;
}

=pod

---++ ObjectMethod passwd( $user, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU is undef, it will try to add the user, failing
if they are already there.

If the $oldPassU matches matches the login's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub passwd {
    my $this = shift;
    $this->{error} = 'System does not support changing passwords';
    return undef;
}

=pod

---++ encrypt( $user, $passwordU, $fresh ) -> $passwordE

Will return an encrypted password. Repeated calls
to encrypt with the same user/passU will return the same passE.

However if the passU is changed, and subsequently changed _back_
to the old user/passU pair, then the old passE is no longer valid.

If $fresh is true, then a new password not based on any pre-existing
salt will be used. Set this if you are generating a completely
new password.

=cut

sub encrypt {
    return '';
}

=pod

---++ ObjectMethod error() -> $string

Return any error raised by the last method call, or undef if the last
method call succeeded.

=cut

sub error {
    return '';
}

=pod

---++ ObjectMethod getEmails($user) -> @emails

Fetch the email address(es) for the given username. Default behaviour
is to look up the users' personal topic.

=cut

sub getEmails {
    my( $this, $login ) = @_;

    my $user = $this->{session}->{users}->findUser( $login, undef, 1 );
    return () unless $user;

    my ($meta, $text) =
      $this->{session}->{store}->readTopic(
          undef, $TWiki::cfg{UsersWebName}, $user->wikiName() );

    my @addresses;

    # Try the form first
    my $entry = $meta->get('FIELD', 'Email');
    if ($entry) {
        push( @addresses, split( /;/, $entry->{value} ) );
    } else {
        # Now try the topic text
        foreach my $l (split ( /\r?\n/, $text  )) {
            if ($l =~ /^\s+\*\s+E-?mail:\s*(.*)$/mi) {
                push @addresses, split( /;/, $1 );
            }
        }
    }

    return @addresses;
}

=pod

---++ ObjectMethod setEmails($user, @emails)

Set the email address(es) for the given username in the user topic.

=cut

sub setEmails {
    my $this = shift;
    my $login = shift;
    my $mails = join( ';', @_ );

    my $user = $this->{session}->{users}->findUser( $login, undef, 1 );
    return () unless $user;

    my ($meta, $text) =
      $this->{session}->{store}->readTopic(
          undef, $TWiki::cfg{UsersWebName}, $user->wikiName() );

    if ($meta->get('FORM')) {
        # use the form if there is one
        $meta->putKeyed( 'FIELD',
                         { name => 'Email',
                           value => $mails,
                           title => 'Email',
                           attributes=> 'h' } );
    } else {
        # otherwise use the topic text
        unless( $text =~ s/^(\s+\*\s+E-?mail:\s*).*$/$1$mails/mi ) {
            $text .= "\n   * Email: $mails\n";
        }
    }

    $this->{session}->{store}->saveTopic( $user, $TWiki::cfg{UsersWebName},
                                  $user->wikiName(), $text, $meta );
}

#returns an array of user objects that relate to a email address
sub findUserByEmail {
    my $this = shift;
    my $email = shift;
    # SMELL: there is no way in TWiki to map from an email back to a user, so
    # we have to cheat. We do this as follows:
    unless( $this->{_MAP_OF_EMAILS} ) {
        $this->{_MAP_OF_EMAILS} = ();
        my $users = $this->{session}->{users}->getAllUsers();
        foreach my $user ( @{$users} ) {
            map { push( @{$this->{_MAP_OF_EMAILS}->{$_}}, $user); } $user->emails();
        }
    }
    return $this->{_MAP_OF_EMAILS}->{$email};
}

1;
