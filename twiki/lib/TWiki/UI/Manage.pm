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

---+ package TWiki::UI::Manage

UI functions for web, topic and user management

=cut

package TWiki::UI::Manage;

use strict;
use Assert;
use TWiki;
use TWiki::UI;
use TWiki::User;
use TWiki::Sandbox;
use Error qw( :try );
use TWiki::OopsException;
use TWiki::UI::Register;

=pod

---++ StaticMethod manage( $session )

=manage= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

=cut

sub manage {
    my $session = shift;

    my $action = $session->{cgiQuery}->param( 'action' );

    if( $action eq 'createweb' ) {
        _createWeb( $session );
    } elsif( $action eq 'changePassword' ) {
        TWiki::UI::Register::changePassword( $session );
    } elsif ($action eq 'bulkRegister') {
        TWiki::UI::Register::bulkRegister( $session );
    } elsif( $action eq 'deleteUserAccount' ) {
        _removeUser( $session );
    } elsif( $action eq 'editSettings' ) {
        _editSettings( $session );
    } elsif( $action eq 'saveSettings' ) {
        _saveSettings( $session );
    } elsif( $action ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'unrecognized_action',
                                    params => $action );
    } else {
        throw TWiki::OopsException( 'attention', def => 'missing_action' );
    }
}

# Renames the user's topic (with renaming all links) and
# removes user entry from passwords. CGI parameters:
sub _removeUser {
    my $session = shift;

    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $query = $session->{cgiQuery};
    my $user = $session->{user};

    my $password = $query->param( 'password' );

    # check if user entry exists
    if( $user && !$user->passwordExists()) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'notwikiuser',
                                    params => $user->stringify() );
    }

    #check to see it the user we are trying to remove is a member of a group.
    #initially we refuse to delete the user
    #in a later implementation we will remove the from the group (if Access.pm implements it..)
    my @groups = $user->getGroups();
    if ( scalar( @groups ) > 0 ) { 
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'in_a_group',
                                    params =>
                                    [ $user->stringify(),
                                      join(', ',
                                           map { $_->stringify() }
                                           @groups ) ] );
    }

    unless( $user->checkPassword( $password ) ) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'wrong_password');
    }

    $user->remove();

    throw TWiki::OopsException( 'attention',
                                def => 'remove_user_done',
                                web => $webName,
                                topic => $topic,
                                params => $user->webDotWikiName() );
}

sub _isValidHTMLColor {
    my $c = shift;
    return $c =~ m/^(#[0-9a-f]{6}|black|silver|gray|white|maroon|red|purple|fuchsia|green|lime|olive|yellow|navy|blue|teal|aqua)/i;

}

sub _createWeb {
    my $session = shift;

    my $topicName = $session->{topicName};
    my $webName = $session->{webName};
    my $query = $session->{cgiQuery};
    my $user = $session->{user};

    my $webBGColor = $query->param( 'webbgcolor' ) || '';
    my $siteMapWhat = $query->param( 'sitemapwhat' ) || '';
    my $siteMapUseTo = $query->param( 'sitemapuseto' ) || '';
    my $noSearchAll = $query->param( 'nosearchall' ) || '';

    # check permission, user authorized to create web here?
    my $parent = undef; # default is root if no parent web
    if( $webName =~ m|^(.*)[./](.*?)$| ) {
        $parent = $1;
    }
    TWiki::UI::checkAccess( $session, $parent, undef,
                            'CHANGE', $session->{user} );

    my $newWeb = $query->param( 'newweb' ) || '';
    unless( $newWeb ) {
        throw TWiki::OopsException( 'attention', def => 'web_missing' );
    }
    unless ( TWiki::isValidWebName( $newWeb, 1 )) {
        throw TWiki::OopsException
          ( 'attention', def =>'invalid_web_name', params => $newWeb );
    }
    $newWeb = TWiki::Sandbox::untaintUnchecked( $newWeb );

    my $baseWeb = $query->param( 'baseweb' ) || '';
    unless( $session->{store}->webExists( $baseWeb )) {
        throw TWiki::OopsException
          ( 'attention', def => 'base_web_missing', params => $baseWeb );
    }
    $baseWeb = TWiki::Sandbox::untaintUnchecked( $baseWeb );

    my $newTopic = $query->param( 'newtopic' ) || $TWiki::cfg{HomeTopicName};
    # SMELL: check that it is a valid topic name?
    $newTopic = TWiki::Sandbox::untaintUnchecked( $newTopic );

    if( $session->{store}->webExists( $newWeb )) {
        throw TWiki::OopsException
          ( 'attention', def => 'web_exists', params => $newWeb );
    }

    unless( _isValidHTMLColor( $webBGColor )) {
        throw TWiki::OopsException
          ( 'attention', def => 'invalid_web_color',
            params => $webBGColor );
    }

    # create the empty web
    my $opts =
      {
       WEBBGCOLOR => $webBGColor,
       SITEMAPWHAT => $siteMapWhat,
       SITEMAPUSETO => $siteMapUseTo,
       NOSEARCHALL => $noSearchAll,
      };
    $opts->{SITEMAPLIST} = 'on' if( $siteMapWhat );

    my $err = $session->{store}->createWeb( $user, $newWeb, $baseWeb, $opts );
    if( $err ) {
        throw TWiki::OopsException
          ( 'attention', def => 'web_creation_error',
            params => [ $newWeb, $err ] );
    }

    # everything OK, redirect to last message
    throw TWiki::OopsException
      ( 'attention',
        web => $newWeb,
        topic => $newTopic,
        def => 'created_web' );
}

=pod

---++ StaticMethod rename( $session )

=rename= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Rename the given topic. Details of the new topic name are passed in CGI
parameters:

| =skin= | skin(s) to use |
| =newweb= | new web name |
| =newtopic= | new topic name |
| =breaklock= | |
| =attachment= | |
| =confirm= | if defined, requires a second level of confirmation |
| =currentwebonly= | if defined, searches current web only for links to this topic |
| =nonwikiword= | if defined, a non-wikiword is acceptable for the new topic name |

=cut

sub rename {
    my $session = shift;

    my $oldTopic = $session->{topicName};
    my $oldWeb = $session->{webName};
    my $query = $session->{cgiQuery};
    my $action = $query->param( 'action' ) || '';

    if( $action eq 'renameweb' ) {
        _renameweb( $session );
        return;
    }

    my $newTopic = $query->param( 'newtopic' ) || '';
    $newTopic = TWiki::Sandbox::untaintUnchecked( $newTopic );

    my $newWeb = $query->param( 'newweb' ) || '';
    unless( !$newWeb || TWiki::isValidWebName( $newWeb, 1 )) {
        throw TWiki::OopsException
          ( 'attention', def =>'invalid_web_name', params => $newWeb );
    }
    $newWeb = TWiki::Sandbox::untaintUnchecked( $newWeb );

    my $attachment = $query->param( 'attachment' );
    # SMELL: test for valid attachment name?
    $attachment = TWiki::Sandbox::untaintUnchecked( $attachment );

    my $lockFailure = '';
    my $breakLock = $query->param( 'breaklock' );

    my $confirm = $query->param( 'confirm' );
    my $doAllowNonWikiWord = $query->param( 'nonwikiword' ) || '';
    my $store = $session->{store};

    $newTopic =~ s/\s//go;
    $newTopic =~ s/$TWiki::cfg{NameFilter}//go;
    $newTopic = ucfirst $newTopic;   # Item3270

    $attachment ||= '';

    TWiki::UI::checkWebExists( $session, $oldWeb, $oldTopic, 'rename' );
    # Item3270: Wrap topic existence into extra try/catch block to
    #           check for the same name starting with a lower case letter.
    try {
        TWiki::UI::checkTopicExists( $session, $oldWeb, $oldTopic, 'rename');
    } catch TWiki::OopsException with {
        $oldTopic = lcfirst $oldTopic;
        TWiki::UI::checkTopicExists( $session, $oldWeb, $oldTopic, 'rename');
    };

    if( $newTopic && !TWiki::isValidWikiWord( $newTopic ) ) {
        unless( $doAllowNonWikiWord ) {
            throw TWiki::OopsException( 'attention',
                                        web => $oldWeb,
                                        topic => $oldTopic,
                                        def => 'not_wikiword',
                                        params => [ $newTopic ] );
        }
        # Filter out dangerous characters (. and / may cause
        # issues with pathnames
        $newTopic =~ s![./]!_!g;
        $newTopic =~ s/($TWiki::cfg{NameFilter})//go;
    }

    if ( $attachment) {
        # Does old attachment exist?
        unless( $store->attachmentExists( $oldWeb, $oldTopic,
                                          $attachment )) {
			my $tmplname = $query->param( 'template' ) || '';
            throw TWiki::OopsException(
                'attention',
                web => $oldWeb, topic => $oldTopic,
                def => ($tmplname eq 'deleteattachment') ? 'delete_err' : 'move_err',
                keep => 1,
                params => [
                    $newWeb, $newTopic,
                    $attachment,
                    $session->{i18n}->maketext('Attachment does not exist')
                   ] );
        }

        if( $newWeb && $newTopic ) {
            TWiki::UI::checkTopicExists( $session, $newWeb,
                                         $newTopic, 'rename');

            # does new attachment already exist?
            if( $store->attachmentExists( $newWeb, $newTopic,
                                          $attachment )) {
                throw TWiki::OopsException(
                    'attention',
                    def => 'move_err',
                    web => $oldWeb, topic => $oldTopic,
                    keep => 1,
                    params => [
                        $newWeb, $newTopic,
                        $attachment,
                        $session->{i18n}->maketext(
                            'Attachment already exists in new topic')
                       ] );
            }
        } # else fall through to new topic screen
    } elsif( $newTopic ) {
        ( $newWeb, $newTopic ) =
          $session->normalizeWebTopicName( $newWeb, $newTopic );

        TWiki::UI::checkWebExists( $session, $newWeb, $newTopic, 'rename' );
        if( $store->topicExists( $newWeb, $newTopic)) {
            throw TWiki::OopsException( 'attention',
                                        def => 'rename_topic_exists',
                                        web => $oldWeb,
                                        topic => $oldTopic,
                                        params => [ $newWeb, $newTopic ] );
        }
    }

    TWiki::UI::checkAccess( $session, $oldWeb, $oldTopic,
                            'rename', $session->{user} );

    # Has user selected new name yet?
    if( ! $newTopic || $confirm ) {
        # Must be able to view the source to rename it
        TWiki::UI::checkAccess( $session, $oldWeb, $oldTopic,
                                'view', $session->{user} );
        _newTopicScreen( $session,
                         $oldWeb, $oldTopic,
                         $newWeb, $newTopic,
                         $attachment,
                         $confirm, $doAllowNonWikiWord );
        return;
    }

    # Update references in referring pages - not applicable to attachments.
    my $refs;
    unless( $attachment ) {
        $refs = _getReferringTopicsListFromURL
          ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic );
    }
    move( $session, $oldWeb, $oldTopic, $newWeb, $newTopic,
          $attachment, $refs );

    my $new_url;
    if ( $newWeb eq $TWiki::cfg{TrashWebName} &&
         $oldWeb ne $TWiki::cfg{TrashWebName} ) {

        # deleting something

        if( $attachment ) {
            # go back to old topic after deleting an attachment
            $new_url = $session->getScriptUrl( 0, 'view', $oldWeb, $oldTopic );

        } else {
            # redirect to parent topic, if set
            my ( $meta, $text ) =
              $store->readTopic( undef, $newWeb, $newTopic, undef );
            my $parent = $meta->get( 'TOPICPARENT' );
            my( $parentWeb, $parentTopic );
            if( $parent && defined $parent->{name} ) {
                ( $parentWeb, $parentTopic ) =
                  $session->normalizeWebTopicName( '', $parent->{name} );
            }
            if( $parentTopic &&
                !( $parentWeb eq $oldTopic && $parentTopic eq $oldTopic ) &&
                  $store->topicExists( $parentWeb, $parentTopic ) ) {
                $new_url = $session->getScriptUrl(
                    0, 'view', $parentWeb, $parentTopic );
            } else {
                $new_url = $session->getScriptUrl( 0, 'view', $oldWeb,
                                                   $TWiki::cfg{HomeTopicName});
            }
        }
    } else {
        #redirect to new topic
        $new_url = $session->getScriptUrl( 0, 'view', $newWeb, $newTopic );
    }

    $session->redirect( $new_url );
}

#| =skin= | skin(s) to use |
#| =newsubweb= | new web name |
#| =newparentweb= | new parent web name |
#| =confirm= | if defined, requires a second level of confirmation.  Currently accepted values are "getlock", "continue", and "cancel" |
sub _renameweb {
    my $session = shift;

    my $oldWeb = $session->{webName};
    my $query = $session->{cgiQuery};
    my $user = $session->{user};

    my $newParentWeb = $query->param( 'newparentweb' ) || '';
    unless ( !$newParentWeb || TWiki::isValidWebName( $newParentWeb, 1 )) {
        throw TWiki::OopsException
          ( 'attention', def => 'invalid_web_name', params => $newParentWeb );
    }
    $newParentWeb = TWiki::Sandbox::untaintUnchecked( $newParentWeb );

    my $newSubWeb = $query->param( 'newsubweb' ) || '';;
    unless ( !$newSubWeb || TWiki::isValidWebName( $newSubWeb, 1 )) {
        throw TWiki::OopsException
          ( 'attention', def => 'invalid_web_name', params => $newSubWeb );
    }
    $newSubWeb = TWiki::Sandbox::untaintUnchecked( $newSubWeb );

    my $newWeb;
    if( $newSubWeb ) {
        if( $newParentWeb ) {
            $newWeb = $newParentWeb.'/'.$newSubWeb;
        } else {
            $newWeb=$newSubWeb;
        }
    }
    my @tmp = split( /[\/\.]/, $oldWeb );
    pop( @tmp );
    my $oldParentWeb = join( '/', @tmp );
    my $newTopic;
    my $lockFailure = '';
    my $breakLock = $query->param( 'breaklock' );
    my $confirm = $query->param( 'confirm' ) || '';
    my $doAllowNonWikiWord = $query->param( 'nonwikiword' ) || '';
    my $store = $session->{store};
    my $security = $session->{security};

    TWiki::UI::checkWebExists(
        $session, $oldWeb, $TWiki::cfg{WebPrefsTopicName}, 'rename' );

    if( $newWeb ) {
        if( $newParentWeb ) {
            # SMELL: need to check change permissions of new parent web
            TWiki::UI::checkWebExists(
                $session, $newParentWeb,
                $TWiki::cfg{WebPrefsTopicName}, 'rename' );
        }

        if( $store->webExists( $newWeb )) {
            throw TWiki::OopsException(
                'attention',
                def => 'rename_web_exists',
                web => $oldWeb,
                topic => $TWiki::cfg{WebPrefsTopicName},
                params => [ $newWeb, $TWiki::cfg{WebPrefsTopicName} ] );
        }
    }

    if( ! $newWeb || $confirm ) {

        my %refs;
        my $refs0;
        my $refs1;
        my $totalReferralAccess = 1;
        my $totalWebAccess = 1;
        my $modifyingLockedTopics;
        my $movingLockedTopics;
        my %webTopicInfo;
        my @webList;

        # get a topic list for all the topics referring to this web,
        # and build up a hash containing permissions and lock info.
        $refs0 = getReferringTopics( $session, $oldWeb, undef, 0 );
        $refs1 = getReferringTopics( $session, $oldWeb, undef, 1 );
        foreach my $ref (sort keys %$refs0) {
            $refs{$ref} = $refs0->{$ref};
        }
        foreach my $ref (sort keys %$refs1) {
            $refs{$ref} = $refs1->{$ref};
        }
        $webTopicInfo{referring}{refs0} = $refs0;
        $webTopicInfo{referring}{refs1} = $refs1;

        my $lease_ref;
        foreach my $ref (sort keys %refs) {
            if(defined($ref) && $ref ne "") {
                $ref =~ s/\./\//go;
                my (@path) = split(/\//,$ref);
                my $webTopic = pop(@path);
                my $webIter = join("/",@path);

                $webIter = TWiki::Sandbox::untaintUnchecked( $webIter );
                $webTopic = TWiki::Sandbox::untaintUnchecked( $webTopic );
                if($confirm eq 'getlock') {
                    $store->setLease( $webIter, $webTopic, $user,
                                      $TWiki::cfg{LeaseLength});
                    $lease_ref=$store->getLease($webIter,$webTopic);
                } elsif ($confirm eq 'cancel') {
                    $lease_ref=$store->getLease($webIter,$webTopic);
                    if($lease_ref->{user} eq $user) {
                        $store->clearLease( $webIter, $webTopic );
                    }
                }
                my $wit = $webIter.'/'.$webTopic;
                $webTopicInfo{modify}{$wit}{leaseuser} = $lease_ref->{user};
                $webTopicInfo{modify}{$wit}{leasetime}=$lease_ref->{taken};

                $modifyingLockedTopics++
                  if(defined($webTopicInfo{modify}{$ref}{leaseuser}) &&
                       $webTopicInfo{modify}{$ref}{leaseuser} ne $user);
                $webTopicInfo{modify}{$ref}{summary} = $refs{$ref};
                $webTopicInfo{modify}{$ref}{access} =
                  $security->checkAccessPermission('change', $user,
                                                   undef, undef, $webTopic,
                                                   $webIter);
                if(!$webTopicInfo{modify}{$ref}{access}) {
                    $webTopicInfo{modify}{$ref}{accessReason} =
                      $security->getReason();
                }
                $totalReferralAccess = 0 unless
                  $webTopicInfo{modify}{$ref}{access};
            }
        }

        # get a topic list for this web and all its subwebs, and build
        # up a hash containing permissions and lock info.
        (@webList) = $store->getListOfWebs('public',$oldWeb);
        unshift(@webList,$oldWeb);
        foreach my $webIter (@webList) {
            $webIter = TWiki::Sandbox::untaintUnchecked( $webIter );
            my @webTopicList=$store->getTopicNames($webIter);
            foreach my $webTopic (@webTopicList) {
                $webTopic = TWiki::Sandbox::untaintUnchecked( $webTopic );
                if( $confirm eq 'getlock' ) {
                    $store->setLease( $webIter, $webTopic, $user,
                                      $TWiki::cfg{LeaseLength});
                    $lease_ref = $store->getLease($webIter,$webTopic);
                } elsif ($confirm eq 'cancel') {
                    $lease_ref = $store->getLease($webIter,$webTopic);
                    if( $lease_ref->{user} eq $user ) {
                        $store->clearLease( $webIter, $webTopic );
                    }
                }
                my $wit = $webIter.'/'.$webTopic;
                $webTopicInfo{move}{$wit}{leaseuser} = $lease_ref->{user};
                $webTopicInfo{move}{$wit}{leasetime} = $lease_ref->{taken};

                $movingLockedTopics++
                  if(defined($webTopicInfo{move}{$wit}{leaseuser}) &&
                       $webTopicInfo{move}{$wit}{leaseuser} ne $user);
                $webTopicInfo{move}{$wit}{access} =
                  $security->checkAccessPermission('rename', $user,
                                                   undef, undef, $webTopic,
                                                   $webIter);
                $webTopicInfo{move}{$wit}{accessReason} =
                  $security->getReason();
                $totalWebAccess = ($totalWebAccess &
                                     $webTopicInfo{move}{$wit}{access});
            }
        }

        if( !$totalReferralAccess || !$totalWebAccess ||
              $movingLockedTopics || $modifyingLockedTopics) {

            # check if the user can rename all the topics in this web.
            push( @{$webTopicInfo{movedenied}},
              grep { !$webTopicInfo{move}{$_}{access} }
                sort keys %{$webTopicInfo{move}} );

            # check if there are any locked topics in this web or
            # its subwebs.
            push( @{$webTopicInfo{movelocked}},
              grep { defined($webTopicInfo{move}{$_}{leaseuser}) &&
                       $webTopicInfo{move}{$_}{leaseuser} ne $user }
                sort keys %{$webTopicInfo{move}} );

            # Next, build up a list of all the referrers which the
            # user doesn't have permission to change.
            push( @{$webTopicInfo{modifydenied}},
              grep { !$webTopicInfo{modify}{$_}{access} }
                sort keys %{$webTopicInfo{modify}} );

            # Next, build up a list of all the referrers which are
            # currently locked.
            push( @{$webTopicInfo{modifylocked}},
              grep { defined($webTopicInfo{modify}{$_}{leaseuser}) &&
                       $webTopicInfo{modify}{$_}{leaseuser} ne $user }
                sort keys %{$webTopicInfo{modify}} );

            unless( $confirm ) {
                my $nocontinue = '';
                if( @{$webTopicInfo{movedenied}} ||
                      @{$webTopicInfo{movelocked}} ) {
                    $nocontinue = 'style="display:none;"';
                }
                my $mvd = join(' ', @{$webTopicInfo{movedenied}} ) || ($session->{i18n}->maketext('(none)'));
                $mvd = substr($mvd, 0, 300).'... (more)'
                  if( length($mvd) > 300);
                my $mvl = join(' ', @{$webTopicInfo{movelocked}} ) || ($session->{i18n}->maketext('(none)'));
                $mvl = substr($mvl, 0, 300).'... (more)'
                  if( length($mvl) > 300);
                my $mdd = join(' ', @{$webTopicInfo{modifydenied}} ) || ($session->{i18n}->maketext('(none)'));
                $mdd = substr($mdd, 0, 300).'... (more)'
                  if( length($mdd) > 300);
                my $mdl = join(' ', @{$webTopicInfo{modifylocked}} ) || ($session->{i18n}->maketext('(none)'));
                $mdl = substr($mdl, 0, 300).'... (more)'
                  if( length($mdl) > 300);
                throw TWiki::OopsException(
                    'attention',
                    web => $oldWeb,
                    topic => '',
                    def => 'rename_web_prerequisites',
                    params => [
                        $mvd, $mvl, $mdd, $mdl,
                        $nocontinue
                       ] );
            }
        }

        if ($confirm eq 'cancel') {
            # redirect to original web
            my $viewURL = $session->getScriptUrl( 0, 'view',
                $oldWeb, $TWiki::cfg{HomeTopicName});
            $session->redirect( $viewURL );
        } elsif( $confirm ne 'getlock' ||
                   ($confirm eq 'getlock' &&
                      $modifyingLockedTopics && $movingLockedTopics )) {
            # Has user selected new name yet?
            _newWebScreen( $session, $oldWeb, $newWeb,
                           $confirm, \%webTopicInfo);
            return;
        }
    }

    # Update references in referring pages 
    my $refs = _getReferringTopicsListFromURL(
        $session, $oldWeb, $TWiki::cfg{HomeTopicName},
        $newWeb, $TWiki::cfg{HomeTopicName} );

    # Now, we can move the web.
    _moveWeb( $session, $oldWeb, $newWeb, $refs );

    # now remove lease on all topics inside $newWeb.
    my (@webList) = $store->getListOfWebs('public',$newWeb);
    unshift(@webList,$newWeb);
    foreach my $webIter (@webList) {
        $webIter = TWiki::Sandbox::untaintUnchecked( $webIter );
        my @webTopicList=$store->getTopicNames($webIter);
        foreach my $webTopic (@webTopicList) {
            $webTopic = TWiki::Sandbox::untaintUnchecked( $webTopic );
            $store->clearLease( $webIter, $webTopic );
        }
    }

    # also remove lease on all referring topics
    foreach my $ref (@$refs) {
        $ref =~ s/\./\//go;
        my (@path)=split(/\//,$ref);
        my $webTopic=pop(@path);
        $webTopic = TWiki::Sandbox::untaintUnchecked( $webTopic );
        my $webIter=join("/",@path);
        $webIter = TWiki::Sandbox::untaintUnchecked( $webIter );
        $store->clearLease( $webIter, $webTopic );
    }

    my $new_url = '';
    if ( $newWeb =~ /^$TWiki::cfg{TrashWebName}\b/ &&
           $oldWeb !~ /^$TWiki::cfg{TrashWebName}\b/ ) {

        # redirect to parent
        if( $oldParentWeb ) {
            $new_url = $session->getScriptUrl( 0, 'view',
                $oldParentWeb, $TWiki::cfg{HomeTopicName} );
        } else {
            $new_url = $session->getScriptUrl( 0, 'view',
                $TWiki::cfg{UsersWebName}, $TWiki::cfg{HomeTopicName} );
        }
    } else {
        # redirect to new web
        $new_url = $session->getScriptUrl( 0, 'view',
            $newWeb, $TWiki::cfg{HomeTopicName} );
    }

    $session->redirect( $new_url );
}

=pod

---++ StaticMethod move($session, $oldWeb, $oldTopic, $newWeb, $newTopic, $attachment, \@refs )

Move the given topic, or an attachment in the topic, correcting refs to the topic in the topic itself, and
in the list of topics (specified as web.topic pairs) in the \@refs array.

   * =$session= - reference to session object
   * =$oldWeb= - name of old web - must be untained
   * =$oldTopic= - name of old topic - must be untained
   * =$newWeb= - name of new web - must be untained
   * =$newTopic= - name of new topic - must be untained
   * =$attachment= - name of the attachment to move (from oldtopic to newtopic) (undef to move the topic) - must be untaineted
   * =\@refs= - array of webg.topics that must have refs to this topic converted
Will throw TWiki::OopsException or TWiki::AccessControlException on an error.

=cut

sub move {
    my( $session, $oldWeb, $oldTopic,
        $newWeb, $newTopic, $attachment, $refs ) = @_;
    my $store = $session->{store};

    if( $attachment ) {
        try {
            $store->moveAttachment( $oldWeb, $oldTopic, $attachment,
                                    $newWeb, $newTopic, $attachment,
                                    $session->{user} );
        } catch Error::Simple with {
            throw TWiki::OopsException(
                'attention',
                web => $oldWeb, topic => $oldTopic,
                def => 'move_err',
                params => [ $newWeb, $newTopic,
                            $attachment,
                            shift->{-text} ] );
        };
        return;
    }

    try {
        $store->moveTopic( $oldWeb, $oldTopic, $newWeb, $newTopic,
                           $session->{user} );
    } catch Error::Simple with {
        throw TWiki::OopsException( 'attention',
                                    web => $oldWeb,
                                    topic => $oldTopic,
                                    def => 'rename_err',
                                    params => [ shift->{-text},
                                                $newWeb,
                                                $newTopic ] );
    };

    my( $meta, $text ) = $store->readTopic( undef, $newWeb, $newTopic );

    if( $oldWeb ne $newWeb ) {
        # If the web changed, replace local refs to the topics
        # in $oldWeb with full $oldWeb.topic references so that
        # they still work.
        my $renderer = $session->{renderer};
        $renderer->replaceWebInternalReferences(
            \$text, $meta,
            $oldWeb, $oldTopic, $newWeb, $newTopic );
    }
    # Ok, now let's replace all self-referential links:
    my $options =
      {
       oldWeb => $newWeb,
       oldTopic => $oldTopic,
       newTopic => $newTopic,
       newWeb => $newWeb,
       inWeb => $newWeb,
       fullPaths => 0,
       spacedTopic => TWiki::spaceOutWikiWord( $oldTopic )
      };
    $options->{spacedTopic} =~ s/ / */g;
    $text = $session->{renderer}->forEachLine(
        $text, \&TWiki::Render::replaceTopicReferences, $options );

    $meta->put( 'TOPICMOVED',
                {
                 from => $oldWeb.'.'.$oldTopic,
                 to   => $newWeb.'.'.$newTopic,
                 date => time(),
                 # SMELL: surely this should be webDotWikiname?
                 by   => $session->{user}->wikiName(),
                } );

    $store->saveTopic( $session->{user}, $newWeb, $newTopic, $text, $meta,
                       { minor => 1, comment => 'rename' } );

    # update referrers - but _not_ including the moved topic
    _updateReferringTopics( $session, $oldWeb, $oldTopic,
                            $newWeb, $newTopic, $refs );
}

# Display screen so user can decide on new web and topic.
sub _newTopicScreen {
    my( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $attachment,
        $confirm, $doAllowNonWikiWord ) = @_;

    my $query = $session->{cgiQuery};
    my $tmplname = $query->param( 'template' ) || '';
    my $tmpl = '';
    my $skin = $session->getSkin();
    my $currentWebOnly = $query->param( 'currentwebonly' ) || '';

    $newTopic = $oldTopic unless ( $newTopic );
    $newWeb = $oldWeb unless ( $newWeb );
    my $nonWikiWordFlag = '';
    $nonWikiWordFlag = 'checked="checked"' if( $doAllowNonWikiWord );

    if( $attachment ) {
        $tmpl = $session->{templates}->readTemplate( $tmplname || 'moveattachment', $skin );
        $tmpl =~ s/%FILENAME%/$attachment/go;
    } elsif( $confirm ) {
        $tmpl = $session->{templates}->readTemplate( 'renameconfirm', $skin );
    } elsif( $newWeb eq $TWiki::cfg{TrashWebName} &&
               $oldWeb ne $TWiki::cfg{TrashWebName}) {
        $tmpl = $session->{templates}->readTemplate( 'renamedelete', $skin );
    } else {
        $tmpl = $session->{templates}->readTemplate( 'rename', $skin );
    }

    # Trashing a topic; look for a non-conflicting name
    if( $newWeb eq $TWiki::cfg{TrashWebName} ) {
        $newTopic = $oldWeb.$newTopic;
        my $n = 1;
        my $base = $newTopic;
        while( $session->{store}->topicExists( $newWeb, $newTopic)) {
            $newTopic = $base.$n;
            $n++;
        }
    }

    $tmpl =~ s/%NEW_WEB%/$newWeb/go;
    $tmpl =~ s/%NEW_TOPIC%/$newTopic/go;
    $tmpl =~ s/%NONWIKIWORDFLAG%/$nonWikiWordFlag/go;

    my $refs;
    my %attributes;
    my %labels;
    my @keys;
    my $search = '';
    if( $currentWebOnly ) {
        $search = $session->{i18n}->maketext('(skipped)');
    } else {
        $refs = getReferringTopics( $session, $oldWeb, $oldTopic, 1 );
        @keys = sort keys %$refs;
        foreach my $entry ( @keys ) {
            $search .= CGI::Tr
              (CGI::td
               ( { class => 'twikiTopRow' },
                 CGI::input( { type => 'checkbox',
                               class => 'twikiCheckBox',
                               name => 'referring_topics',
                               value => $entry,
                               checked => 'checked' } ). " [[$entry]] " ) .
               CGI::td( { class => 'twikiSummary twikiGrayText' },
                        $refs->{$entry} ));
        }
        unless( $search ) {
            $search = ($session->{i18n}->maketext('(none)'));
        } else {
            $search = CGI::start_table().$search.CGI::end_table();
        }
    }
    $tmpl =~ s/%GLOBAL_SEARCH%/$search/o;

    $refs = getReferringTopics( $session, $oldWeb, $oldTopic, 0 );
    @keys = sort keys %$refs;
    $search = '';;
    foreach my $entry ( @keys ) {
        $search .= CGI::Tr
          (CGI::td
           ( { class => 'twikiTopRow' },
             CGI::input( { type => 'checkbox',
                           class => 'twikiCheckBox',
                           name => 'referring_topics',
                           value => $entry,
                           checked => 'checked' } ). " [[$entry]] " ) .
           CGI::td( { class => 'twikiSummary twikiGrayText' },
                    $refs->{$entry} ));
    }
    unless( $search ) {
        $search = ($session->{i18n}->maketext('(none)'));
    } else {
        $search = CGI::start_table().$search.CGI::end_table();
    }
    $tmpl =~ s/%LOCAL_SEARCH%/$search/go;

    $tmpl = $session->handleCommonTags( $tmpl, $oldWeb, $oldTopic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $oldWeb, $oldTopic );
    $session->writeCompletePage( $tmpl );
}

# _moveWeb($session, $oldWeb,  $newWeb, \@refs )
#
# Move the given web, correcting refs to the web in the web itself, and
# in the list of topics (specified as web.topic pairs) in the \@refs array.
# Currently only called by _renameweb
#
# All permissions and lease conflicts should be resolved before calling this method.
#
#    * =$session= - reference to session object
#    * =$oldWeb= - name of old web
#    * =$newWeb= - name of new web
#    * =\@refs= - array of webg.topics that must have refs to this topic converted
# Will throw TWiki::OopsException on an error.

sub _moveWeb {
    my( $session, $oldWeb, $newWeb, $refs ) = @_;
    my $store = $session->{store};

    $oldWeb =~ s/\./\//go;
    $newWeb =~ s/\./\//go;

    my $user = $session->{user};

    if( $store->webExists( $newWeb )) {
        throw TWiki::OopsException( 'attention',
                                    web => $oldWeb,
                                    topic => '',
                                    def => 'rename_web_exists',
                                    params => [ $newWeb ] );
    }

    # update referrers.  We need to do this before moving,
    # because there might be topics inside the newWeb which need updating.
    _updateWebReferringTopics( $session, $oldWeb, $newWeb, $refs );

    try {
        $store->moveWeb( $oldWeb, $newWeb, $user );
    } catch Error::Simple  with {
        my $e = shift;
        throw TWiki::OopsException( 'attention',
                                    web => $oldWeb,
                                    topic => '',
                                    def => 'rename_web_err',
                                    params => [ $e->{-text}, $newWeb ] );
    }
}

# Display screen so user can decide on new web.
# a Refresh mechanism is provided after submission of the form
# so the user can refresh the display until lease conflicts 
# are resolved.

sub _newWebScreen {
    my( $session, $oldWeb, $newWeb,
        $confirm, $webTopicInfoRef ) = @_;

    my $query = $session->{cgiQuery};
    my $tmpl = '';

    $newWeb = $oldWeb unless ( $newWeb );

    my @newParentPath = split( /\//, $newWeb );
    my $newSubWeb = pop( @newParentPath );
    my $newParent = join( '/', @newParentPath );
    my $accessCheckWeb = $newParent;
    my $accessCheckTopic = $TWiki::cfg{WebPrefsTopicName};
    my $templates = $session->{templates};

    if( $confirm eq 'getlock' ) {
        $tmpl = $templates->readTemplate( 'renamewebconfirm' );
    } elsif( $newWeb eq $TWiki::cfg{TrashWebName} ) {
        $tmpl = $templates->readTemplate( 'renamewebdelete' );
    } else {
        $tmpl = $templates->readTemplate( 'renameweb' );
    }

    # Trashing a web; look for a non-conflicting name
    if( $newWeb eq $TWiki::cfg{TrashWebName} ) {
        $newWeb = "$TWiki::cfg{TrashWebName}/$oldWeb";
        my $n = 1;
        my $base = $newWeb;
        while( $session->{store}->webExists( $newWeb )) {
            $newWeb = $base.$n;
            $n++;
        }
    }

    my $subWebStyle = 'style="display:none;"';
    $subWebStyle = '' if $TWiki::cfg{EnableHierarchicalWebs};

    $tmpl =~ s/%SUBWEBSENABLE%/$subWebStyle/g;
    $tmpl =~ s/%NEW_PARENTWEB%/$newParent/go;
    $tmpl =~ s/%NEW_SUBWEB%/$newSubWeb/go;
    $tmpl =~ s/%TOPIC%/$TWiki::cfg{HomeTopicName}/go;

    my( $movelocked, $refdenied, $reflocked ) = ( '', '', '' );
    $movelocked = join(', ', @{$webTopicInfoRef->{movelocked}} )
      if $webTopicInfoRef->{movelocked};
    $movelocked = ($session->{i18n}->maketext('(none)')) unless $movelocked;
    $refdenied = join(', ', @{$webTopicInfoRef->{modifydenied}} )
      if $webTopicInfoRef->{modifydenied};
    $refdenied = ($session->{i18n}->maketext('(none)')) unless $refdenied;
    $reflocked = join(', ', @{$webTopicInfoRef->{modifylocked}} )
      if $webTopicInfoRef->{modifylocked};
    $reflocked = ($session->{i18n}->maketext('(none)')) unless $reflocked;

    $tmpl =~ s/%MOVE_LOCKED%/$movelocked/;
    $tmpl =~ s/%REF_DENIED%/$refdenied/;
    $tmpl =~ s/%REF_LOCKED%/$reflocked/;

    my $submitAction =
      ( $movelocked || $reflocked ) ? 'refresh_prompt' : 'submit_prompt';
    $tmpl =~ s/%RENAMEWEB_SUBMIT%/\%$submitAction\%/go;

    my $refs;
    my %attributes;
    my %labels;
    my @keys;
    my $search = '';

    $refs = ${$webTopicInfoRef}{referring}{refs1};
    @keys = sort keys %$refs;
    foreach my $entry ( @keys ) {
        $search .= CGI::Tr(
            CGI::td(
                { class => 'twikiTopRow' },
                CGI::input(
                    { type => 'checkbox',
                      class => 'twikiCheckBox',
                      name => 'referring_topics',
                      value => $entry,
                      checked => 'checked' } ). " [[$entry]] " ) .
                 CGI::td( { class => 'twikiSummary twikiGrayText' },
                          $refs->{$entry}
                         )
                  );
    }
    unless( $search ) {
        $search = ($session->{i18n}->maketext('(none)'));
    } else {
        $search = CGI::start_table().$search.CGI::end_table();
    }
    $tmpl =~ s/%GLOBAL_SEARCH%/$search/o;

    $refs = $webTopicInfoRef->{referring}{refs0};
    @keys = sort keys %$refs;
    $search = '';
    foreach my $entry ( @keys ) {
        $search .= CGI::Tr
        (CGI::td
          ( { class => 'twikiTopRow' },
            CGI::input( { type => 'checkbox',
                          class => 'twikiCheckBox',
                          name => 'referring_topics',
                          value => $entry,
                          checked => 'checked' } ). " [[$entry]] " ) .
                        CGI::td( { class => 'twikiSummary twikiGrayText' },
                                 $refs->{$entry} ));
    }
    unless( $search ) {
        $search = ($session->{i18n}->maketext('(none)'));
    } else {
        $search = CGI::start_table().$search.CGI::end_table();
    }
    $tmpl =~ s/%LOCAL_SEARCH%/$search/go;

    $tmpl = $session->handleCommonTags( $tmpl, $oldWeb, $TWiki::cfg{HomeTopicName} );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $oldWeb, $TWiki::cfg{HomeTopicName} );
    $session->writeCompletePage( $tmpl );
}

# Returns the list of topics that have been found that refer
# to the renamed topic. Returns a list of topics.
sub _getReferringTopicsListFromURL {
    my( $session, $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;

    my $query = $session->{cgiQuery};
    my @result;
    foreach my $topic ( $query->param( 'referring_topics' ) ) {
        push @result, $topic;
    }
    return \@result;
}

=pod

---++ StaticMethod getReferringTopics($session, $web, $topic, $allWebs) -> \%matches

   * =$session= - the session
   * =$web= - web to search for
   * =$topic= - topic to search for
   * =$allWebs= - 0 to search $web only. 1 to search all webs _except_ $web.
Returns a hash that maps the web.topic name to a summary of the lines that matched. Will _not_ return $web.$topic in the list

=cut

sub getReferringTopics {
    my( $session, $web, $topic, $allWebs ) = @_;
    my $store = $session->{store};
    my $renderer = $session->{renderer};
    $web =~ s#\.#/#go;
    my @webs = ( $web );

    if( $allWebs ) {
        @webs = $store->getListOfWebs();
    }

    my %results;
    foreach my $searchWeb ( @webs ) {
        next if( $allWebs && $searchWeb eq $web );
        my @topicList = $store->getTopicNames( $searchWeb );
        my $searchString;
        my $webString = $web;
        $webString =~ s#[\./]#[\\.\\/]#go;

        if( defined($topic) ) {
            if( $searchWeb eq $web ) {
                $searchString = '\<'.$topic.'\>';
            } else {
                $searchString = '\<'.$webString.'\.'.$topic.'\>';
             }
        } elsif( $searchWeb ne $web ) {
            # search for the *qualified* web name
            $searchString = '\<'.$webString.'\.[A-Za-z0-9]*\>';
        } else {
            # most general search
            $searchString = '\<'.$webString.'\>';
        }
        # Note use of \< and \> to match the empty string at the
        # edges of a word.

        my $matches = $store->searchInWebContent
          ( $searchString,
            $searchWeb, \@topicList,
            { casesensitive => 1, type => 'regex' } );

        foreach my $searchTopic ( keys %$matches ) {
            next if( $searchWeb eq $web && $topic && $searchTopic eq $topic );

            my $t = join( '...', @{$matches->{$searchTopic}});
            $t = $renderer->TML2PlainText( $t, $searchWeb, $searchTopic,
                                           "showvar;showmeta" );
            $t =~ s/^\s+//;
            if( length( $t ) > 100 ) {
                $t =~ s/^(.{100}).*$/$1/;
            }
            $results{$searchWeb.'.'.$searchTopic} = $t;
        };
    }
    return \%results;
}

# Update pages that refer to a page that is being renamed/moved.
# SMELL: this might be done more efficiently if it was behind the
# store interface
sub _updateReferringTopics {
    my ( $session, $oldWeb, $oldTopic, $newWeb, $newTopic, $refs ) = @_;
    my $store = $session->{store};
    my $renderer = $session->{renderer};
    my $user = $session->{user};
    my $options =
      {
       pre => 1, # process lines in PRE blocks
       oldWeb => $oldWeb,
       oldTopic => $oldTopic,
       newWeb => $newWeb,
       newTopic => $newTopic,
       spacedTopic => TWiki::spaceOutWikiWord( $oldTopic )
      };
    $options->{spacedTopic} =~ s/ / */g;

    foreach my $item ( @$refs ) {
        my( $itemWeb, $itemTopic ) =
          $session->normalizeWebTopicName( '', $item );

        if ( $store->topicExists($itemWeb, $itemTopic) ) {
            $store->lockTopic( $user, $itemWeb, $itemTopic );
            try {
                my( $meta, $text ) =
                  $store->readTopic( undef, $itemWeb, $itemTopic, undef );
                $options->{inWeb} = $itemWeb;

                $text = $renderer->forEachLine
                  ( $text, \&TWiki::Render::replaceTopicReferences, $options );
                $meta->forEachSelectedValue
                  ( qw/^(FIELD|FORM|TOPICPARENT)$/, undef,
                    \&TWiki::Render::replaceTopicReferences, $options );

                $store->saveTopic( $user, $itemWeb, $itemTopic,
                                   $text, $meta,
                                   { minor => 1 } );
            } catch TWiki::AccessControlException with {
                my $e = shift;
                $session->writeWarning( $e->stringify() );
            } finally {
                $store->unlockTopic( $user, $itemWeb, $itemTopic );
            };
        }
    }
}

# Update pages that refer to a web that is being renamed/moved.
sub _updateWebReferringTopics {
    my ( $session, $oldWeb, $newWeb, $refs ) = @_;
    my $store = $session->{store};
    my $renderer = $session->{renderer};
    my $user = $session->{user};
    my $options =
      {
       oldWeb => $oldWeb,
       newWeb => $newWeb
      };

    foreach my $item ( @$refs ) {
        my( $itemWeb, $itemTopic ) =
          $session->normalizeWebTopicName( '', $item );

        if ( $store->topicExists($itemWeb, $itemTopic) ) {
            $store->lockTopic( $user, $itemWeb, $itemTopic );
            try {
                my( $meta, $text ) =
                  $store->readTopic( undef, $itemWeb, $itemTopic, undef );
                $options->{inWeb} = $itemWeb;

                $text = $renderer->forEachLine
                  ( $text, \&TWiki::Render::replaceWebReferences, $options );
                $meta->forEachSelectedValue
                  ( qw/^(FIELD|FORM|TOPICPARENT)$/, undef,
                    \&TWiki::Render::replaceWebReferences, $options );

                $store->saveTopic( $user, $itemWeb, $itemTopic,
                                   $text, $meta,
                                   { minor => 1 } );
            } catch TWiki::AccessControlException with {
                my $e = shift;
                $session->writeWarning( $e->stringify() );
            } finally {
                $store->unlockTopic( $user, $itemWeb, $itemTopic );
            };
        }
    }
}

sub _editSettings {
    my $session = shift;
    my $topic = $session->{topicName};
    my $web = $session->{webName};

    my( $meta, $text ) =
      $session->{store}->readTopic( $session->{user}, $web, $topic, undef );
    my ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();

    my $settings = "";

    my @fields = $meta->find( 'PREFERENCE' );
    foreach my $field ( @fields ) {
       my $name  = $field->{name};
       my $value = $field->{value};
       $settings .= '   * ' . (($field->{type} eq 'Local') ? 'Local' : 'Set').
         ' '.$name.' = '.$value."\n";
    }

    my $skin = $session->getSkin();
    my $tmpl = $session->{templates}->readTemplate( 'settings', $skin );
    $tmpl = $session->handleCommonTags( $tmpl, $web, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $web, $topic );

    $tmpl =~ s/%TEXT%/$settings/o;
    $tmpl =~ s/%ORIGINALREV%/$orgRev/g;

    $session->writeCompletePage( $tmpl );

}

sub _saveSettings {
    my $session = shift;
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $user = $session->{user};

    # set up editing session
    my ( $currMeta, $currText ) =
      $session->{store}->readTopic( undef, $web, $topic, undef );
    my $newMeta = new TWiki::Meta( $session, $web, $topic );
    $newMeta->copyFrom( $currMeta );

    my $query = $session->{cgiQuery};
    my $settings = $query->param( 'text' );
    my $originalrev = $query->param( 'originalrev' );

    $newMeta->remove( 'PREFERENCE' );  # delete previous settings
    $settings =~ s($TWiki::regex{setVarRegex})
      (&_handleSave($web, $topic, $1, $2, $3, $newMeta))mgeo;

    my $saveOpts = {};
    $saveOpts->{minor} = 1;            # don't notify
    $saveOpts->{forcenewrevision} = 1; # always new revision

    # Merge changes in meta data
    if ( $originalrev ) {
        my ( $date, $author, $rev ) = $newMeta->getRevisionInfo();
        # If the last save was by me, don't merge
        if ( $rev ne $originalrev && !$author->equals( $user )) {
            $newMeta->merge( $currMeta );
        }
    }

    try {
        $session->{store}->saveTopic( $user, $web, $topic,
                                    $currText, $newMeta, $saveOpts );
    } catch Error::Simple with {
        throw TWiki::OopsException( 'attention',
                                    def => 'save_error',
                                    web => $web,
                                    topic => $topic,
                                    params => shift->{-text} );
    };
    my $viewURL = $session->getScriptUrl( 0, 'view', $web, $topic );
    $session->redirect( $viewURL );
    return;

}

sub _handleSave {
  my( $web, $topic, $type, $name, $value, $meta ) = @_;

  $value =~ s/^\s*(.*?)\s*$/$1/ge;

  my $args =
    {
     name =>  $name,
     title => $name,
     value => $value,
     type =>  $type
    };
  $meta->putKeyed( 'PREFERENCE', $args );
  return '';

}

1;
