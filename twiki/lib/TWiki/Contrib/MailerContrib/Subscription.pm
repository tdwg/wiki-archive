# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 1999-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
#
# As per the GPL, removal of this notice is prohibited.

use strict;

=pod

---+ package TWiki::Contrib::MailerContrib::Subscription
Object that represents a single subscription of a user to
notification on a page. A subscription is expressed as a page
spec (which may contain wildcards) and a depth of children of
matching pages that the user is subscribed to.

=cut

package TWiki::Contrib::MailerContrib::Subscription;

=pod

---++ ClassMethod new($pages, $childDepth, $news)
   * =$pages= - Wildcarded expression matching subscribed pages
   * =$childDepth= - Depth of children of $topic to notify changes for. Defaults to 0
   * =$mode= - ! if this is a non-changes subscription and the topics should
   be mailed evebn if there are no changes. ? to mail the full topic only
   if there are changes. undef to mail changes only.
Create a new subscription.

=cut

sub new {
    my ( $class, $topics, $depth, $mode ) = @_;

    my $this = bless( {}, $class );

    $this->{topics} = $topics;
    $this->{depth} = $depth;
    $this->{mode} = $mode;

    $topics =~ s/[^\w\*]//g;
    $topics =~ s/\*/\.\*\?/g;
    $this->{topicsRE} = qr/^$topics$/;

    return $this;
}

=pod

---++ ObjectMethod stringify() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub stringify {
    my $this = shift;

    my $record = $this->{topics} . ($this->{mode} || '');
    # convert RE back to wildcard
    $record =~ s/\.\*\?/\*/;
    $record .= " ($this->{depth})" if ( $this->{depth} );
    return $record;
}

=pod

---++ ObjectMethod matches($topic, $db, $depth) -> boolean
   * =$topic= - Topic object we are checking
   * =$db= - TWiki::Contrib::MailerContrib::UpData database of parent names
   * =$depth= - If non-zero, check if the parent of the given topic matches as well. undef = 0.
Check if we match this topic. Recurses up the parenthood tree seeing if
this is a child of a parent that matches within the depth range.

=cut

sub matches {
    my ( $this, $topic, $db, $depth ) = @_;
    return 0 unless ($topic);

    return 1 if ( $topic =~ $this->{topicsRE} );

    $depth = $this->{depth} unless defined( $depth );
    $depth ||= 0;

    if ( $depth ) {
        my $parent = $db->getParent( $topic );
        $parent =~ s/^.*\.//;
        return $this->matches( $parent, $db, $depth - 1 ) if ( $parent );
    }

    return 0;
}

=pod

---++ ObjectMethod getMode() -> $mode
Return ! if this is a non-changes subscription and the topics should
be mailed even if there are no changes. ? to mail the full topic only
if there are changes. undef to mail changes only.

=cut

sub getMode {
    my $this = shift;

    return $this->{mode};
}

1;
