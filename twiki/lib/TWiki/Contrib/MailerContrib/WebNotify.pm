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

use TWiki;

use TWiki::Contrib::MailerContrib::Subscriber;
use TWiki::Contrib::MailerContrib::Subscription;

=pod

---+ package TWiki::Contrib::MailerContrib::WebNotify
Object that represents the contents of a %NOTIFYTOPIC% topic in a TWiki web

=cut

package TWiki::Contrib::MailerContrib::WebNotify;

=pod

---++ ClassMethod new($web, $topic)
Create a new object by parsing the content of the given topic in the
given web. This is the normal way to load a %NOTIFYTOPIC% topic. If the
topic does not exist, it will create an empty object.

=cut

sub new {
    my ( $class, $session, $web, $topic ) = @_;

    my $this = bless( {}, $class );

    $this->{web} = $web;
    $this->{topic} = $topic || $TWiki::cfg{NotifyTopicName};
    $this->{text} = '';
    $this->{session} = $session;

    if( $session->{store}->topicExists( $web, $topic )) {
        $this->_load();
    }

    return $this;
}

=pod

---++ ObjectMethod writeWebNotify()
Write the object to the %NOTIFYTOPIC% topic it was read from.
If there is a problem writing the topic (e.g. it is locked),
the method will return an error message. If everything is ok
it will return undef.

=cut

sub writeWebNotify {
    my $this = shift;
    return $this->{session}->{store}->saveTopic(
        $this->{session}->{user},
        $this->{web},
        $this->{topic},
        $this->{text} . $this->stringify(),
        undef, # meta
        { dontlog => 1, unlock => 1 });
}

=pod

---++ ObjectMethod getSubscriber($name, $noAdd)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$noAdd= - If false or undef, a new subscriber will be created for this name
Get a subscriber from the list of subscribers, and return a reference
to the Subscriber object. If $noAdd is true, and the subscriber is not
found, undef will be returned. Otherwise a new Subscriber object will
be added if necessary.

=cut

sub getSubscriber {
    my ( $this, $name, $noAdd ) = @_;

    my $subscriber = $this->{subscribers}{$name};
    unless ( $noAdd || defined( $subscriber )) {
        $subscriber =
          new TWiki::Contrib::MailerContrib::Subscriber( $this->{session},
                                                         $name );
        $this->{subscribers}{$name} = $subscriber;
    }
    return $subscriber;
}

=pod

---++ ObjectMethod getSubscribers()
Get a list of all subscriber names (unsorted)

=cut

sub getSubscribers {
    my ( $this ) = @_;

    return keys %{$this->{subscribers}};
}

=pod

---++ ObjectMethod subscribe($name, $topics, $depth)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$topics= - wildcard expression giving topics to subscribe to
   * =$depth= - Child depth to scan (default 0)
   * =$mode= - ! if this is a non-changes subscription and the topics should
   be mailed evebn if there are no changes. ? to mail the full topic only
   if there are changes. undef to mail changes only.
Add a subscription, adding the subscriber if necessary.

=cut

sub subscribe {
    my ( $this, $name, $topics, $depth, $mode ) = @_;

    my $subscriber = $this->getSubscriber( $name );
    my $sub = new TWiki::Contrib::MailerContrib::Subscription( $topics, $depth, $mode );
    $subscriber->subscribe( $sub );
}

=pod

---++ ObjectMethod unsubscribe($name, $topics, $depth)
   * =$name= - Name of subscriber (wikiname with no web or email address)
   * =$topics= - wildcard expression giving topics to subscribe to
   * =$depth= - Child depth to scan (default 0)
Add an unsubscription, adding the subscriber if necessary. An unsubscription
is a specific request to ignore notifications for a topic for this
particular subscriber.

=cut

sub unsubscribe {
    my ( $this, $name, $topics, $depth ) = @_;

    my $subscriber = $this->getSubscriber( $name );
    my $sub = new TWiki::Contrib::MailerContrib::Subscription( $topics, $depth );
    $subscriber->unsubscribe( $sub );
}

=pod

---++ ObjectMethod stringify() -> string
Return a string representation of this object, in %NOTIFYTOPIC% format.

=cut

sub stringify {
    my $this = shift;

    my $page = $this->{text};

    foreach my $name ( sort keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        $page .= $subscriber->stringify() . "\n";
    }

    return $page;
}

=pod

---++ ObjectMethod processChange($change, $db, $changeSet, $seenSet, $allSet)
   * =$change= - ref of a TWiki::Contrib::Mailer::Change
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parent references
   * =$changeSet= - ref of a hash mapping emails to sets of changes
   * =$seenSet= - ref of a hash recording indices of topics already seen
   * =$allSet= - ref of a hash that maps topics to email addresses for news subscriptions
Find all subscribers that are interested in the given change. Only the most
recent change to each topic listed in the .changes file is retained. This
method does _not_ change this object.

=cut

sub processChange {
    my ( $this, $change, $db, $changeSet, $seenSet, $allSet ) = @_;

    my $topic = $change->{TOPIC};

    foreach my $name ( keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        my $subs = $subscriber->isSubscribedTo( $topic, $db );
        if ($subs && !$subscriber->isUnsubscribedFrom( $topic, $db )) {
            my $emails = $subscriber->getEmailAddresses();
            if( $emails ) {
                foreach my $email ( @$emails ) {
		    #print "##################### $email\n"; # REMOVE-ME
                    if ($subs->getMode()) { # ? or !
                        push( @{$allSet->{$topic}}, $email );
                    } else {
                        my $at = $seenSet->{$email}{$topic};
                        if ( $at ) {
                            $changeSet->{$email}[$at - 1]->merge( $change );
                        } else {
                            $seenSet->{$email}{$topic} =
                              push( @{$changeSet->{$email}}, $change );
                        }
                    }
                }
            }
        }
    }
}

=pod

---++ ObjectMethod processCompulsory($topic, $db, \%allSet)
   * =$topic= - topic name
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parent references
   * =\%allSet= - ref of a hash that maps topics to email addresses for news subscriptions

=cut

sub processCompulsory {
    my ($this, $topic, $db, $allSet) = @_;

    foreach my $name ( keys %{$this->{subscribers}} ) {
        my $subscriber = $this->{subscribers}{$name};
        my $subs = $subscriber->isSubscribedTo( $topic, $db );
        next unless $subs;
        my $mode = $subs->getMode();
        next if (!defined($mode) || $mode ne '!');
        unless( $subscriber->isUnsubscribedFrom( $topic, $db )) {
            my $emails = $subscriber->getEmailAddresses();
            if( $emails ) {
                foreach my $address (@$emails) {
                    push( @{$allSet->{$topic}}, $address );
                }
            }
        }
    }
}

=pod

---++ ObjectMethod isEmpty() -> boolean
Return true if there are no subscribers

=cut

sub isEmpty {
    my $this = shift;
    return ( scalar( keys %{$this->{subscribers}} ) == 0 );
}

# PRIVATE parse a topic extracting formatted lines
sub _load {
    my $this = shift;

    my ( $meta, $text ) = $this->{session}->{store}->readTopic(
        undef, $this->{web}, $this->{topic} );
    $this->{meta} = $meta;
    # join \ terminated lines
    $text =~ s/\\\r?\n//gs;
    my $webRE = qr/$TWiki::cfg{UsersWebName}\.|%MAINWEB%\./o;
    foreach my $line ( split ( /\n/, $text )) {
        if ( $line =~ /^\s+\*\s$webRE?($TWiki::regex{wikiWordRegex})\s+\-\s+($TWiki::regex{emailAddrRegex})/o ) {
            # * Main.WikiName - email@domain
            # * %MAINWEB%.WikiName - email@domain
            if ( $1 ne $TWiki::cfg{DefaultUserWikiName} ) {
                # Add email address to list if non-guest and non-duplicate
                $this->subscribe( $2, '*', 0 );
            }
        }
        elsif ( $line =~ /^\s+\*\s$webRE?($TWiki::regex{wikiWordRegex})\s*$/o ) {
            # * Main.WikiName
            # %MAINWEB%.WikiName
            # WikiName
            $this->subscribe($1, '*', 0 );
        }
        elsif ( $line =~ /^\s+\*\s($TWiki::regex{emailAddrRegex})\s*$/o ) {
            # * email@domain
            $this->subscribe($1, '*', 0 );
        }
        elsif ( $line =~ /^\s+\*\s($TWiki::regex{emailAddrRegex})\s*:(.*)$/o ) {
            # * email@domain: topics
            $this->_parsePages( $1, $3 );
        }
        elsif ( $line =~ /^\s+\*\s$webRE?($TWiki::regex{wikiWordRegex})\s*:(.*)$/o ) {
            # * Main.WikiName: topics
            # * %MAINWEB%.WikiName: topics
            if ( $2 ne $TWiki::cfg{DefaultUserWikiName} ) {
                $this->_parsePages( $1, $2 );
            }
        }
        else {
            $this->{text} .= "$line\n";
        }
    }
}

# PRIVATE parse a pages list, adding subscriptions as appropriate
sub _parsePages {
    my ( $this, $who, $spec ) = @_;
    my $ospec = $spec;
    $spec =~ s/,/ /g;
    while ( $spec =~ s/^\s*([+-])?\s*([\w\*]+)([!?]?)\s*(?:\((\d+)\))?// ) {
        my $mode = $3 or 0;
        my $kids = $4 or 0;
        if ( $1 && $1 eq '-' ) {
            $this->unsubscribe( $who, $2, $kids );
        } else {
            $this->subscribe( $who, $2, $kids, $mode );
        }
    }
    if ( $spec =~ m/\S/ ) {
        print STDERR "Badly formatted subscription list $ospec";
    }
}

1;
