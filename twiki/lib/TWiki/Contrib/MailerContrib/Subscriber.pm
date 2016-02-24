# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
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

use strict;

=pod

---+ package TWiki::Contrib::MailerContrib::Subscriber
Object that represents a subscriber to notification. A subscriber is
a name (which may be a wikiName or an email address) and a list of
subscriptions which describe the topis subscribed to, and
unsubscriptions representing topics they are specifically not
interested in. The subscriber
name may also be a group, so it may expand to many email addresses.

=cut

package TWiki::Contrib::MailerContrib::Subscriber;

use TWiki;
use Assert;

=pod

---++ ClassMethod new($name)
   * =$name= - Wikiname, with no web, or email address, of user targeted for notification
Create a new user.

=cut

sub new {
    my ( $class, $session, $name ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );

    $this->{session} = $session;
    $this->{name} = $name;

    return $this;
}

=pod

---++ ObjectMethod getEmailAddresses() -> list
Get a list of email addresses for the user(s) represented by this
subscription

=cut

sub getEmailAddresses {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Contrib::MailerContrib::Subscriber')) if DEBUG;

    unless ( defined( $this->{emails} )) {
        if ( $this->{name} =~ /^$TWiki::regex{emailAddrRegex}/o ) {
            push( @{$this->{emails}}, $this->{name} );
        } else {
            my $user = $this->{session}->{users}->findUser
                       ( $this->{name}, undef, 1 );
            if( $user ) {
                push( @{$this->{emails}}, $user->emails() );
            }
            else {
                # unknown - can't find an email
                $this->{emails} = ();
            }
        }
    }
    return $this->{emails};
}

=pod

---++ ObjectMethod subscribe($subs)
   * =$subs= - Subscription object
Add a new subscription to this subscriber object.
The subscription will always be added, even if there is
a wildcard overlap with an existing subscription.

=cut

sub subscribe {
    my ( $this, $subs ) = @_;

    push( @{$this->{subscriptions}}, $subs );
}

=pod

---++ ObjectMethod unsubscribe($subs)
   * =$subs= - Subscription object
Add a new unsubscription to this subscriber object.
The unsubscription will always be added, even if there is
a wildcard overlap with an existing subscription or unsubscription.

An unsubscription is a statement of the subscribers desire _not_
to be notified of changes to this topic.

=cut

sub unsubscribe {
    my ( $this, $subs ) = @_;

    push( @{$this->{unsubscriptions}}, $subs );
}

=pod

---++ ObjectMethod isSubscribedTo($topic) -> $subscription
   * =$topic= - Topic object we are checking
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parents
Check if we have a subscription to the given topic. Return the subscription
that matches if we do, undef otherwise.

=cut

sub isSubscribedTo {
   my ( $this, $topic, $db ) = @_;

   foreach my $subscription ( @{$this->{subscriptions}} ) {
       if ( $subscription->matches( $topic, $db )) {
           return $subscription;
       }
   }

   return undef;
}

=pod

---++ ObjectMethod isUnsubscribedFrom($topic) -> $subscription
   * =$topic= - Topic object we are checking
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parents
Check if we have an unsubscription from the given topic. Return the subscription that matches if we do, undef otherwise.

=cut

sub isUnsubscribedFrom {
   my ( $this, $topic, $db ) = @_;

   foreach my $subscription ( @{$this->{unsubscriptions}} ) {
       if ( $subscription->matches( $topic, $db )) {
           return $subscription;
       }
   }

   return undef;
}

=pod

---++ ObjectMethod stringify() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub stringify {
    my $this = shift;
    my $subs = join( ' ',
                     map { $_->stringify(); }
                     @{$this->{subscriptions}} );
    my $unsubs = join( " - ",
                       map { $_->stringify(); }
                       @{$this->{unsubscriptions}} );
    $unsubs = " - $unsubs" if $unsubs;

    return "   * " . $this->{name} . ": " .
      $subs . $unsubs;
}

1;
