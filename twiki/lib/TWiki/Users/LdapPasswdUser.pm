# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2007 TWiki Contributors. All Rights Reserved. 
# TWiki Contributors are listed in the AUTHORS file in the root of 
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Users::LdapPasswdUser;

use Net::LDAP;
use Assert;
use strict;
use TWiki::Users::Password;
use Error qw( :try );

@TWiki::Users::LdapPasswdUser::ISA = qw( TWiki::Users::Password );

=pod

---+ package TWiki::Users::LdapPasswdUser

Password manager that uses LDAP to manage users and passwords.

Subclass of [[TWikiUsersPasswordDotPm][ =TWiki::Users::Password= ]].
See documentation of that class for descriptions of the methods of this class.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new( $session ), $class );
    
    $this->{error} = undef;

    if( $TWiki::cfg{LdapPasswd}{Encoding} eq 'md5' ) {
        require Digest::MD5;

    } elsif( $TWiki::cfg{LdapPasswd}{Encoding} eq 'sha1' ) {
        require MIME::Base64;
        import MIME::Base64 qw( encode_base64 );
        require Digest::SHA1;
        import Digest::SHA1 qw( sha1 );
    }

    return $this;
}


sub encrypt {
    my ( $this, $user, $passwd, $fresh ) = @_;

    ASSERT($this->isa( 'TWiki::Users::LdapPasswdUser')) if DEBUG;

    $passwd ||= '';

    if( $TWiki::cfg{LdapPasswd}{Encoding} eq 'sha1') {
        my $encodedPassword = '{SHA}'.
	    MIME::Base64::encode_base64( Digest::SHA1::sha1( $passwd ) );
        # don't use chomp, it relies on $/
        $encodedPassword =~ s/\s+$//;
        return $encodedPassword;

    } elsif ( $TWiki::cfg{LdapPasswd}{Encoding} eq 'crypt' ) {
	    # by David Levy, Internet Channel, 1997
	    # found at http://world.inch.com/Scripts/htpasswd.pl.html

        my $salt;
        $salt = $this->fetchPass( $user ) unless $fresh;
        if ( $fresh || !$salt ) {
            my @saltchars = ( 'a'..'z', 'A'..'Z', '0'..'9', '.', '/' );
            $salt = $saltchars[int(rand($#saltchars+1))] .
		$saltchars[int(rand($#saltchars+1)) ];
        }
        return crypt( $passwd, substr( $salt, 0, 2 ) );

    } elsif ( $TWiki::cfg{LdapPasswd}{Encoding} eq 'md5' ) {
        # SMELL: what does this do if we are using a htpasswd file?
	my $toEncode= "$user:$TWiki::cfg{AuthRealm}:$passwd";
	return Digest::MD5::md5_hex( $toEncode );

    } elsif ( $TWiki::cfg{LdapPasswd}{Encoding} eq 'plain' ) {
	return $passwd;

    }
    die 'Unsupported password encoding '.
	$TWiki::cfg{LdapPasswd}{Encoding};
}


sub _getLdapEntry {
    my ( $this, $user ) = @_;

    ASSERT($this->isa( 'TWiki::Users::LdapPasswdUser')) if DEBUG;

    $this->{error} = undef;

    # create LDAP object
    $this->{ldap} = Net::LDAP->new($TWiki::cfg{LdapPasswd}{Host});
    if (!$this->{ldap}) {
	$this->{error} = "$@";
	return;
    }

    $this->{ldap}->bind( 
			 $TWiki::cfg{LdapPasswd}{AdminDN}, 
			 password => $TWiki::cfg{LdapPasswd}{AdminPwd}
			 );

    if (!defined $this->{ldap}) {
	$this->{error} = 'Couldn\'t contact LDAP server...';
	return;
    }
    
    # perform a search
    my $entries = $this->{ldap}->search( 
		base => $TWiki::cfg{LdapPasswd}{BaseDN},
		filter => "(& (uid=$user) (!(employeeType=*Disabled*)))"
	      );

    if (!($entries->error eq "Success")) {
	$this->{error} = $entries->error;
    }
    
    my $entry = $entries->entry(0);
    
    $this->{ldap}->unbind;   # take down session 

    return $entry;
}


sub fetchPass {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::LdapPasswdUser')) if DEBUG;
    my $ret = undef;

    if( $user ) {

	my $entry = $this->_getLdapEntry($user);

	if( $entry && ($entry->get_value("uid") eq $user)) {
	    $ret = $entry->get_value("userPassword");
	} else {
	    $this->{error} = 'Login invalid';
	}
	
    } else {
        $this->{error} = 'No user';
    }
    return $ret;
}


sub checkPassword {
    my ( $this, $user, $password ) = @_;
    ASSERT($this->isa( 'TWiki::Users::LdapPasswdUser')) if DEBUG;
    my $encryptedPassword = $this->encrypt( $user, $password );

    
    #die "User: $user";
    #die "UPwd: $password";
    #die "EPwd: $encryptedPassword";

    $this->{error} = undef;

    my $pw = $this->fetchPass( $user );
    return 0 unless defined $pw;
    # $pw will be 0 if there is no pw

    return 1 if( $pw && ($encryptedPassword eq $pw) );
    # pw may validly be '', and must match an unencrypted ''. This is
    # to allow for sysadmins removing the password field in .htpasswd in
    # order to reset the password.
    return 1 if ( defined $password && $pw eq '' && $password eq '' );

    $this->{error} = 'Invalid user/password';
    return 0;
}


sub error {
    my $this = shift;
    return $this->{error} || undef;
}


sub getEmails {
    my( $this, $login) = @_;

    my $entry = $this->_getLdapEntry($login);

    my @addresses;

    if (defined $entry) {
        push( @addresses, $entry->get_value("mail") );

    } else {
	# this warning message will show up on cron output log
	print "LdapPasswdUser.pm: Couldn't find LDAP record for user $login\n";
	print "LdapPasswdUser.pm: Error message: " . $this->{error} . "\n";

    }

    return @addresses;
}

1;
