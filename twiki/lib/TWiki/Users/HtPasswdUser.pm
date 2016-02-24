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

---+ package TWiki::Users::HtPasswdUser

Support for htpasswd and htdigest format password files.

Subclass of [[TWikiUsersPasswordDotPm][ =TWiki::Users::Password= ]].
See documentation of that class for descriptions of the methods of this class.

=cut

package TWiki::Users::HtPasswdUser;

use strict;
use Assert;
use Error qw( :try );
use TWiki::Users::Password;

@TWiki::Users::HtPasswdUser::ISA = qw( TWiki::Users::Password );

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale ();
    }
	# no point calling rand() without this 
    # See Camel-3 pp 800.  "Do not call =srand()= multiple times in your
    # program ... just do it once at the top of your program or you won't
    # get random numbers out of =rand()=
    srand( time() ^ ($$ + ($$ << 15)) );
}

sub new {
    my( $class, $session) = @_;
    my $this = bless( $class->SUPER::new($session), $class );
    $this->{error} = undef;
    if( $TWiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {
        require Digest::MD5;
    } elsif( $TWiki::cfg{Htpasswd}{Encoding} eq 'sha1' ) {
        require MIME::Base64;
        import MIME::Base64 qw( encode_base64 );
        require Digest::SHA1;
        import Digest::SHA1 qw( sha1 );
    }
    return $this;
}

sub _readPasswd {
    my $data = {};
    if ( ! -e $TWiki::cfg{Htpasswd}{FileName} ) {
        return $data;
    }
    open( IN_FILE, "<$TWiki::cfg{Htpasswd}{FileName}" ) ||
      throw Error::Simple( $TWiki::cfg{Htpasswd}{FileName}.' open failed: '.$! );
    local $/ = undef;
    foreach my $line ( split(/\r?\n/, <IN_FILE>) ) {
        if( $line =~ /^(.*?):(.*?)(?::(.*))?$/ ) {
            $data->{$1}->{pass} = $2;
            $data->{$1}->{emails} = $3 || '';
        }
    }
    close( IN_FILE );
    return $data;
}

sub _dumpPasswd {
    my $db = shift;
    my $s = '';
    foreach ( sort keys %$db ) {
        $s .= $_.':'.$db->{$_}->{pass}.':'.$db->{$_}->{emails}."\n";
    }
    return $s;
}

sub _savePasswd {
    my $db = shift;

    umask( 077 );
    open( FILE, ">$TWiki::cfg{Htpasswd}{FileName}" ) ||
      throw Error::Simple( $TWiki::cfg{Htpasswd}{FileName}.
                             ' open failed: '.$! );

    print FILE _dumpPasswd($db);
    close( FILE);
}

sub encrypt {
    my ( $this, $user, $passwd, $fresh ) = @_;

    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;

    $passwd ||= '';

    if( $TWiki::cfg{Htpasswd}{Encoding} eq 'sha1') {
        my $encodedPassword = '{SHA}'.
          MIME::Base64::encode_base64( Digest::SHA1::sha1( $passwd ) );
        # don't use chomp, it relies on $/
        $encodedPassword =~ s/\s+$//;
        return $encodedPassword;

    } elsif ( $TWiki::cfg{Htpasswd}{Encoding} eq 'crypt' ) {
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

    } elsif ( $TWiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {
        # SMELL: what does this do if we are using a htpasswd file?
		my $toEncode= "$user:$TWiki::cfg{AuthRealm}:$passwd";
		return Digest::MD5::md5_hex( $toEncode );

    } elsif ( $TWiki::cfg{Htpasswd}{Encoding} eq 'plain' ) {
		return $passwd;

	}
    die 'Unsupported password encoding '.
      $TWiki::cfg{Htpasswd}{Encoding};
}

sub fetchPass {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;
    my $ret = undef;

    if( $user ) {
        try {
            my $db = _readPasswd();
            if( exists $db->{$user} ) {
                $ret = $db->{$user}->{pass};
            } else {
                $this->{error} = 'Login invalid';
            }
        } catch Error::Simple with {
            $this->{error} = $!;
        };
    } else {
        $this->{error} = 'No user';
    }
    return $ret;
}

sub passwd {
    my ( $this, $user, $newUserPassword, $oldUserPassword ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;

    if( defined( $oldUserPassword )) {
        unless( $oldUserPassword eq '1') {
            return 0 unless $this->checkPassword( $user, $oldUserPassword );
        }
    } elsif( $this->fetchPass( $user )) {
        $this->{error} = $user.' already exists';
        return 0;
    }

    try {
        my $db = _readPasswd();
        $db->{$user}->{pass} = $this->encrypt( $user, $newUserPassword, 1 );
        $db->{$user}->{emails} ||= '';
        _savePasswd( $db );
    } catch Error::Simple with {
        $this->{error} = $!;
        return undef;
    };

    $this->{error} = undef;
    return 1;
}

sub deleteUser {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;
    my $result = undef;
    $this->{error} = undef;

    try {
        my $db = _readPasswd();
        unless( $db->{$user} ) {
            $this->{error} = 'No such user '.$user;
        } else {
            delete $db->{$user};
            _savePasswd( $db );
            $result = 1;
        }
    } catch Error::Simple with {
        $this->{error} = shift->{-text};
    };
    return $result;
}

sub checkPassword {
    my ( $this, $user, $password ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;
    my $encryptedPassword = $this->encrypt( $user, $password );

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

    return $this->{error};
}

sub getEmails {
    my( $this, $user ) = @_;

    # first try the mapping cache
    my $db = _readPasswd();
    if( $db->{$user}->{emails}) {
        return split(/;/, $db->{$user}->{emails});
    }

    # fall back to the default approach
    return $this->SUPER::getEmails( $user );
}

sub setEmails {
    my $this = shift;
    my $user = shift;
    die unless ($user);

    my $db = _readPasswd();
    unless ($db->{$user}) {
        $db->{$user}->{pass} = '';
    }
    if( scalar(@_) ) {
        $db->{$user}->{emails} = join(';', @_);
    } else {
        $db->{$user}->{emails} = '';
    }
    _savePasswd($db);
}

1;

