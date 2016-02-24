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

=pod

---+ package TWiki::Users

Singleton object that handles mapping of users to wikinames and
vice versa, and user authentication checking.

=cut

package TWiki::Users;

use strict;
use Assert;
use TWiki::User;
use TWiki::Time;

BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=pod

---++ ClassMethod new ($session, $impl)

Construct the user management object

=cut

sub new {
    my ( $class, $session ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );

    $this->{session} = $session;

    my $implPasswordManager = $TWiki::cfg{PasswordManager};
    $implPasswordManager = 'TWiki::Users::Password' if( $implPasswordManager eq 'none' );
    eval "use $implPasswordManager";
    die "Password Manager: $@" if $@;
    $this->{passwords} = $implPasswordManager->new( $session );

    my $implUserMappingManager = $TWiki::cfg{UserMappingManager};
    $implUserMappingManager = 'TWiki::Users::TWikiUserMapping' if( $implUserMappingManager eq 'none' );
    eval "use $implUserMappingManager";
    die "User Mapping Manager: $@" if $@;
    $this->{usermappingmanager} = $implUserMappingManager->new( $session );

    $this->{login} = {};
    $this->{wikiname} = {};

    $this->{CACHED} = 0;

    # create the guest user
    $this->createUser( $TWiki::cfg{DefaultUserLogin},
                       $TWiki::cfg{DefaultUserWikiName} );

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
    
    $this->{passwords}->finish();
    $this->{usermappingmanager}->finish();

    my $wikinames = $this->{wikiname};
    while (my ($wikiname,$user) = each %$wikinames) {
       $user->{groups} = ();
    }
    $this->{wikiname}  =  {};
    $this->{login}     =  {};
}

#returns a ref to an array of all group objects found.
sub getAllGroups() {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;

    unless (defined($this->{grouplist})) {
        # Always add $cfg{SuperAdminGroup}
        my $sawAdmin = 0;
        @{$this->{grouplist}} =
          map { $sawAdmin ||= ($_->wikiName() eq $TWiki::cfg{SuperAdminGroup}); $_ }
            $this->{usermappingmanager}->getListOfGroups();
        if (!$sawAdmin) {
            push(@{$this->{grouplist}}, $this->findUser($TWiki::cfg{SuperAdminGroup}));
        }
    }
    return \@{$this->{grouplist}};
}


# Get a list of user objects from a text string containing a
# list of user names. Used by User.pm
sub expandUserList {
    my( $this, $names, $expand ) = @_;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;

    $names ||= '';
    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $names =~ s/(<[^>]*>)//go;     # Remove HTML tags

    $names =~ s/\s*([$TWiki::regex{mixedAlphaNum}_\.\,\s\%]*)\s*(.*)/$1/go;

    my @l = map { $this->findUser( $_ ) } split( /[\,\s]+/, $names );
    return \@l;
}

=pod

---++ ObjectMethod findUser( $name [, $wikiname] [, $nocreate ] ) -> $userObject

   * =$name= - login name or wiki name
   * =$wikiname= - optional, wikiname for created user
   * =$nocreate= - optional, disable creation of user object for user not found

Find the user object corresponding to =$name=, which may be either a
login name or a wiki name. If =$name= is found (either in the list
of login names or the list of wiki names) the corresponding
user object is returned. In this case =$wikiname= is ignored.

If they are not found, and =$nocreate= is true, then return undef.

If =$nocreate= is false, then a user object is returned even if
the user is not known.

If =$nocreate= is false, and no =$wikiname= is given, then the
=$name= is used for both login name and wiki name.

If nocreate is off, then a default user will be created with their wikiname
set the same as their login name. This user/wiki name pair can be overridden
by a later createUser call when the correct wikiname is known, if necessary.

=cut

sub findUser {
    my( $this, $name, $wikiname, $dontCreate ) = @_;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;
    $name ||= $TWiki::cfg{DefaultUserLogin};
    my $object;

    #$this->{session}->writeDebug("Looking for $name / $wikiname / $dontCreate");

    # is it a cached login name?
    $object = $this->{login}{$name};
    return $object if $object;

    # remove pointless tag; we'll be looking there anyway
    $name =~ s/^%MAINWEB%.//;

    if( $name =~ m/^$TWiki::regex{webNameRegex}\.$TWiki::regex{wikiWordRegex}$/o ) {
        # may be web.wikiname; try the cache
        $object = $this->{wikiname}{$name};
        return $object if $object;
    }

    # prepend the mainweb and try again in the cache
    if( $name =~ /^$TWiki::regex{wikiWordRegex}$/ ) {
        $object = $this->{wikiname}{"$TWiki::cfg{UsersWebName}.$name"};
        return $object if $object;
    }

    # not cached

    # if no wikiname is given, try and recover it from
    # TWikiUsers
    unless( $wikiname ) {
        $wikiname = $this->lookupLoginName( $name );
    }

    if( !$wikiname &&
        $name =~ m/^($TWiki::regex{webNameRegex}\.)?$TWiki::regex{wikiWordRegex}$/o ) {
        my $t = $name;
        $t = "$TWiki::cfg{UsersWebName}.$t" unless $1;
        # not in TWiki users as a login name; see if it is
        # a WikiName
        my $lUser = $this->lookupWikiName( $t );
        if( $lUser ) {
            # it's a wikiname
            $name = $lUser;
            $wikiname = $t;
        }
    }

    # if we haven't matched a wikiname yet and we've been told
    # not to create, then abandon ship
    return undef if ( !$wikiname && $dontCreate );

    unless( $wikiname ) {
        # default to wikiname being the same as name.
        # Commented out because this warning is too common, and tends to
        # flood the logs.
        # $this->{session}->writeWarning("$name does not exist in TWikiUsers - is this a bogus user?") unless( $name =~ /Group$/ );
        $wikiname = $name;
    }

    return $this->createUser( $name, $wikiname );
}

=pod

---++ ObjectMethod findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of user objects for the users that have this email registered
with the password manager.

=cut

sub findUserByEmail {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;

    my $user = $this->{passwords}->findUserByEmail(@_);
    return $user;
}

=pod

---++ ObjectMethod createUser( $login, $wikiname ) -> $userobject

Create a user, and insert them in the maps (overwriting any current entry).
Use this instead of findUser when you want to be sure you are not going to
pick up any default user created by findUser. All parameters are required.

=cut

sub createUser {
    my( $this, $name, $wikiname ) = @_;

    my $object = new TWiki::User( $this->{session}, $name, $wikiname );
    if ( defined ($object) ) {
        $this->{login}{$object->login()} = $object;
        $this->{wikiname}{$object->webDotWikiName()} = $object;
    }

    return $object;
}

=pod

---++ ObjectMethod addUserToMapping( $user ) -> $topicName

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa.

=cut

sub addUserToMapping {
    my ( $this, $user, $me ) = @_;

    return $this->{usermappingmanager}->addUserToMapping($user, $me);
}

# Translates username (e.g. jsmith) to Web.WikiName
# (e.g. Main.JaneSmith)
sub lookupLoginName {
    my( $this, $loginUser ) = @_;

    return undef unless $loginUser;

    $loginUser =~ s/$TWiki::cfg{NameFilter}//go;
    return $this->{usermappingmanager}->lookupLoginName($loginUser);

}

# Translates Web.WikiName (e.g. Main.JaneSmith) to
# username (e.g. jsmith)
sub lookupWikiName {
    my( $this, $wikiName ) = @_;

    return undef unless $wikiName;

    $wikiName =~ s/$TWiki::cfg{NameFilter}//go;
    $wikiName = "$TWiki::cfg{UsersWebName}.$wikiName"
      unless $wikiName =~ /\./;

    return $this->{usermappingmanager}->lookupWikiName($wikiName);
}

#TODO: I was under the impression that this list would not contain every user, 
#but i can't prove it..
#using TWikiUserMapping, this hash will contain users listed in a group, that don't exist
#Also, this list will contain a user that is in the current session file, even after it was removed from the system ( we don't check the validity of the user specified in the session - and thus a person can log in, then have their account removed, and until the session expires, they can still edit.)
sub getAllLoadedUsers {
    my $this = shift;
    my $includeGroups = shift || 0;

    my @list = ();
    foreach my $key (sort keys(%{$this->{wikiname}})) {
        my $u = $this->{wikiname}{$key};
	if ($u->isa( 'TWiki::User')) {
	        push(@list, $u) unless (($includeGroups == 0) && ($u->isGroup()));
	} else {
		die $u;
	}
    }

    return \@list;
}

#TODO: we need to re-write and bring together the different UserCaches
#this seems to be a safer list than getAllLoadedUsers()
#however, if there is a non-existant user in the TWikiUsers topic, it will be here.
sub getAllUsers {
    my( $this ) = @_;

    my @list = $this->{usermappingmanager}->getListOfAllWikiNames();
    @list = sort(@list);
#    die join(', ', @list);

    my @userlist= ();

    foreach my $u (@list) {
        my $user = $this->findUser($u);
        push(@userlist, $user) if ($user->isa( 'TWiki::User'));
    }

    return \@userlist;
}


1;
