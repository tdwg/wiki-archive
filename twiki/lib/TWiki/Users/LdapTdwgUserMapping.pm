# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Sven Dowideit, SvenDowideit@home.org.au
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

---+ package TWiki::Users::LdapTdwgUserMapping

User mapping is the process by which TWiki maps from a username (a login name) to a wikiname and back. It is also
where groups are maintained.

By default TWiki maintains user topics and group topics in the %MAINWEB% that
define users and group. These topics are
   * !TWikiUsers - stores a mapping from usernames to TWiki names
   * !WikiName - for each user, stores info about the user
   * !GroupNameGroup - for each group, a topic ending with "Group" stores a list of users who are part of that group.

Many sites will want to override this behaviour, for example to get users and groups from a corporate database.

This class implements the basic TWiki behaviour using topics to store users, but is also designed to be subclassed
so that other services can be used.

Subclasses should be named 'XxxxUserMapping' so that configure can find them.

*All* methods in this class should be implemented by subclasses.

=cut

    package TWiki::Users::LdapTdwgUserMapping;

use strict;
use strict;
use Assert;
use TWiki::User;
use TWiki::Time;
use Net::LDAP;
use Error qw( :try );

#@TWiki::Users::LdapTdwgUserMapping::ISA = qw( TWiki::Users::TWikiUserMapping );

=pod

---++ ClassMethod new( $session ) -> $object

Constructs a new user mapping handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( {}, $class );
    $this->{session} = $session;

    %{$this->{U2W}} = ();
    %{$this->{W2U}} = ();

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

# callback for search function to collate results
sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    return unless $group;
    my $groupObject = $ref->{users}->findUser( $group );
    push (@{$ref->{list}}, $groupObject) if $groupObject;
}

# get a list of groups defined in this TWiki 

=pod

---++ ObjectMethod getListOfGroups( ) -> @listOfUserObjects

Get a list of groups defined by the mapping manager. By default,
TWiki defines groups using topics in the Main web. Subclasses should
override this to list groups from their own databases.

Returns a list of TWiki::User objects, one per group.

=cut

sub getListOfGroups {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users::LdapTdwgUserMapping')) if DEBUG;

    my @list;
    my $users = $this->{session}->{users};

    $this->{session}->{search}->searchWeb
      (
       _callback     => \&_collateGroups,
       _cbdata       =>  { list => \@list, users => $users },
       inline        => 1,
       search        => "Set GROUP =",
       web           => $TWiki::cfg{UsersWebName},
       topic         => "*Group",
       type          => 'regex',
       nosummary     => 'on',
       nosearch      => 'on',
       noheader      => 'on',
       nototal       => 'on',
       noempty       => 'on',
       format     => '$web.$topic',
       separator     => '',
      );

    return @list;
}

=pod

---++ ObjectMethod addUserToMapping( $user, $addingUser ) -> $topicName

RSP: extended from parent class.

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa. The default implementation uses a special topic called
"TWikiUsers" in the users web. Subclasses will provide other implementations
(usually stubs if they have other ways of mapping usernames to wikinames).

    Group names must be acceptable to $TWiki::cfg{NameFilter}

$user is the user being added. $addingUser is the user doing the adding.

=cut

sub addUserToMapping {
    # this is handled by TDWG Typo3 instance
    return;
}

=pod

---++ ObjectMethod lookupLoginName($username) -> $wikiName

Map a username to the corresponding wikiname. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupLoginName {
    my ($this, $loginUser) = @_;

    $this->_loadMapping();
    return $this->{U2W}{$loginUser};
}

=pod

---++ Objectmethod lookupWikiName($wikiname) -> $username

Map a wikiname to the corresponding username. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupWikiName {
    my ($this, $wikiName) = @_;

    $this->_loadMapping();
    return $this->{W2U}{$wikiName};
}

=pod

---++ ObjectMethod getListOfAllWikiNames() -> @wikinames

Returns a list of all wikinames of users known to the mapping manager.

=cut

sub getListOfAllWikiNames {
    my ( $this ) = @_;
    ASSERT($this->isa( 'TWiki::Users::LdapTdwgUserMapping')) if DEBUG;

    $this->_loadMapping();
    return keys(%{$this->{W2U}});
}

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).
#
# RSP: extended from parent class.
sub _loadMapping {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users::LdapTdwgUserMapping')) if DEBUG;

    return if $this->{CACHED};
    $this->{CACHED} = 1;

    # load all non-blocked users from LDAP directory
    my $ldap = Net::LDAP->new($TWiki::cfg{LdapPasswd}{Host});

    $ldap->bind( 
		 $TWiki::cfg{LdapPasswd}{AdminDN}, 
		 password => $TWiki::cfg{LdapPasswd}{AdminPwd}
		 );
    
    # perform a search
    my $entries = $ldap->search( 
				 base => $TWiki::cfg{LdapPasswd}{BaseDN},
				 filter => "(!(employeeType=*Disabled*))"
				 );

    my @entries = $entries->entries();
    foreach my $entry ( @entries ) {
	my $wikiname = $entry->get_value("uid");
	# user name and login name are the same in TDWG user database
	$this->_cacheUser(undef, $wikiname, $wikiname) if $wikiname;
    }

    $ldap->unbind;   # take down session 
}

sub _cacheUser {
    my($this, $web, $wUser, $lUser) = @_;
    $web ||= $TWiki::cfg{UsersWebName};
    $lUser ||= $wUser;# userid
    # FIXME: Should filter in for security...
    # SMELL: filter prevents use of password managers with wierd usernames,
    # like the DOMAIN\username used in the swamp of despair.
	$lUser =~ s/$TWiki::cfg{NameFilter}//go;
    my $wwn = $web.'.'.$wUser;
    $this->{U2W}{$lUser} = $wwn;
    $this->{W2U}{$wwn} = $lUser;
}

=pod

---++ ObjectMethod groupMembers($group) -> @members

Return a list of user objects that are members of this group. Should only be
called on groups.

Note that groups may be defined recursively, so a group may contain other
groups. This method should *only* return users i.e. all contained groups
should be fully expanded.

=cut

sub groupMembers {
    my $this = shift;
    my $group = shift;
    ASSERT($this->isa( 'TWiki::Users::LdapTdwgUserMapping')) if DEBUG;
    my $store = $this->{session}->{store};

    if( !defined $group->{members} &&
	$store->topicExists( $group->{web}, $group->{wikiname} )) {
        my $text =
          $store->readTopicRaw( undef,
                                $group->{web}, $group->{wikiname},
                                undef );
        foreach( split( /\r?\n/, $text ) ) {
            if( /$TWiki::regex{setRegex}GROUP\s*=\s*(.+)$/ ) {
                next unless( $1 eq 'Set' );
                # Note: if there are multiple GROUP assignments in the
                # topic, only the last will be taken.
                $group->{members} = 
		    $this->{session}->{users}->expandUserList( $2 );
            }
        }
        # backlink the user to the group
        foreach my $user ( @{$group->{members}} ) {
            push( @{$user->{groups}}, $group );
        }
    }

    return $group->{members};
}

=pod

---++ ObjectMethod isGroup($user) -> boolean

Establish if a user object refers to a user group or not.

The default implementation is to check if the wikiname of the user ends with
'Group'. Subclasses may override this behaviour to provide alternative
    interpretations. The $TWiki::cfg{SuperAdminGroup} is recognized as a
group no matter what it's name is.

=cut

sub isGroup {
    my ($this, $user) = @_;
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;

    return $user->wikiName() =~ /Group$/;
}

1;