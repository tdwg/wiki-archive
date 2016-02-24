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

---+ package TWiki::Access

A singleton object of this class manages the access control database.

=cut

package TWiki::Access;

use strict;
use Assert;

=pod

---++ ClassMethod new()

Construct a new singleton object to manage the permissions
database.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    $this->{session} = $session;

    %{$this->{GROUPS}} = ();

    return $this;
}

=pod

---++ ObjectMethod permissionsSet (  $web  ) -> $boolean

Are there any security restrictions for this Web
(ignoring settings on individual pages).

=cut

sub permissionsSet {
    my( $this, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Access')) if DEBUG;

    my $permSet = 0;

    my @types = qw/ALLOW DENY/;
    my @actions = qw/CHANGE VIEW/;
    my $prefs = $this->{session}->{prefs};

  OUT: foreach my $type ( @types ) {
        foreach my $action ( @actions ) {
            my $pref = $type . 'WEB' . $action;
            my $prefValue = $prefs->getWebPreferencesValue( $pref, $web ) || '';
            if( $prefValue =~ /\S/ ) {
                $permSet = 1;
                last OUT;
            }
        }
    }

    return $permSet;
}

=pod

---++ ObjectMethod getReason() -> $string

Return a string describing the reason why the last access control failure
occurred.

=cut

sub getReason {
    my $this = shift;

    return $this->{failure};
}

=pod

---++ ObjectMethod checkAccessPermission( $action, $user, $text, $meta, $topic, $web ) -> $boolean

Check if user is allowed to access topic
   * =$action=  - 'VIEW', 'CHANGE', 'CREATE', etc.
   * =$user=    - User object
   * =$text=    - If undef or '': Read '$theWebName.$theTopicName' to check permissions
   * =$meta=    - If undef, but =$text= is defined, then metadata will be parsed from =$text=. If defined, then metadata embedded in =$text= will be ignored. Always ignored if =$text= is undefined. Settings in =$meta= override * Set settings in plain text.
   * =$topic=   - Topic name to check, e.g. 'SomeTopic' *undef to check web perms only)
   * =$web=     - Web, e.g. 'Know'
If the check fails, the reason can be recoveered using getReason.

=cut

sub checkAccessPermission {
    my( $this, $mode, $user, $text, $meta, $topic, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Access')) if DEBUG;
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;

    undef $this->{failure};

    #print STDERR "Check $mode access ", $user->stringify()," to ", ($web||'undef'), '.', ($topic||'undef'),"\n";

    # super admin is always allowed
    if( $user->isAdmin() ) {
        #print STDERR $user->stringify() . " - ADMIN\n";
        return 1;
    }

    $mode = uc( $mode );  # upper case

    my $prefs = $this->{session}->{prefs};

    my $allowText;
    my $denyText;

    # extract the * Set (ALLOWTOPIC|DENYTOPIC)$mode
    if( defined $text ) {
        # override topic permissions.
        $allowText = $prefs->getTextPreferencesValue(
            'ALLOWTOPIC'.$mode, $text, $meta, $web, $topic );
        $denyText = $prefs->getTextPreferencesValue(
            'DENYTOPIC'.$mode, $text, $meta, $web, $topic );
    } elsif( $topic ) {
        $allowText = $prefs->getTopicPreferencesValue( 'ALLOWTOPIC'.$mode,
                                                       $web, $topic );
        $denyText = $prefs->getTopicPreferencesValue( 'DENYTOPIC'.$mode,
                                                      $web, $topic );
    }

    # Check DENYTOPIC
    if( defined( $denyText )) {
        if( $denyText =~ /\S$/ ) {
            if( $user->isInList( $denyText )) {
                $this->{failure} = $this->{session}->{i18n}->maketext('access denied on topic');
                #print STDERR $this->{failure},"\n";
                return 0;
            }
        } else {
            # If DENYTOPIC is empty, don't deny _anyone_
            #print STDERR "DENYTOPIC is empty\n";
            return 1;
        }
    }

    # Check ALLOWTOPIC. If this is defined the user _must_ be in it
    if( defined( $allowText ) && $allowText =~ /\S/ ) {
        if( $user->isInList( $allowText )) {
            #print STDERR "in ALLOWTOPIC\n";
            return 1;
        }
        $this->{failure} = $this->{session}->{i18n}->maketext('access not allowed on topic');
        #print STDERR $this->{failure},"\n";
        return 0;
    }

    # Check DENYWEB, but only if DENYTOPIC is not set (even if it
    # is empty - empty means "don't deny anybody")
    unless( defined( $denyText )) {
        $denyText =
          $prefs->getWebPreferencesValue( 'DENYWEB'.$mode, $web );
        if( defined( $denyText ) && $user->isInList( $denyText )) {
            $this->{failure} = $this->{session}->{i18n}->maketext('access denied on web');
            #print STDERR $this->{failure},"\n";
            return 0;
        }
    }

    # Check ALLOWWEB. If this is defined and not overridden by
    # ALLOWTOPIC, the user _must_ be in it.
    $allowText = $prefs->getWebPreferencesValue( 'ALLOWWEB'.$mode, $web );

    if( defined( $allowText ) && $allowText =~ /\S/ ) {
        unless( $user->isInList( $allowText )) {
            $this->{failure} = $this->{session}->{i18n}->maketext('access not allowed on web');
            #print STDERR $this->{failure},"\n";
            return 0;
        }
    }

    # Check DENYROOT and ALLOWROOT, but only if web is not defined
    unless( $web ) {
        $denyText =
          $prefs->getPreferencesValue( 'DENYROOT'.$mode, $web );
        if( defined( $denyText ) && $user->isInList( $denyText )) {
            $this->{failure} = $this->{session}->{i18n}->maketext('access denied on root');
            #print STDERR $this->{failure},"\n";
            return 0;
        }

        $allowText = $prefs->getPreferencesValue( 'ALLOWROOT'.$mode, $web );

        if( defined( $allowText ) && $allowText =~ /\S/ ) {
            unless( $user->isInList( $allowText )) {
                $this->{failure} = $this->{session}->{i18n}->maketext('access not allowed on root');
                #print STDERR $this->{failure},"\n";
                return 0;
            }
        }
    }

    #print STDERR "OK, permitted\n";
    #print STDERR "ALLOW: $allowText\n" if defined $allowText;
    #print STDERR "DENY: $denyText\n" if defined $denyText;
    return 1;
}

1;
