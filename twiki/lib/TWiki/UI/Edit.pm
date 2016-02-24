# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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

---+ package TWiki::UI::Edit

Edit command handler

=cut

package TWiki::UI::Edit;

use strict;
use Assert;
use TWiki;
use TWiki::Form;
use TWiki::Plugins;
use TWiki::Prefs;
use TWiki::Store;
use TWiki::UI;
use Error qw( :try );
use TWiki::OopsException;
use CGI qw( -any );

=pod

---++ StaticMethod edit( $session )

Edit command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
Most parameters are in the CGI query:

| =cmd= | Undocumented save command, passed on to save script |
| =onlywikiname= | if defined, requires a wiki name for the topic name if this is a new topic |
| =onlynewtopic= | if defined, and the topic exists, then moans |
| =formtemplate= | name of the form for the topic; will replace existing form |
| =templatetopic= | name of the topic to copy if creating a new topic |
| =skin= | skin(s) to use |
| =topicparent= | what to put in the topic prent meta data |
| =text= | text that will replace the old topic text if a formtemplate is defined (what the heck is this for?) |
| =contenttype= | optional parameter that defines the application type to write into the CGI header. Defaults to text/html. |
| =action= | Optional. If supplied, use the edit${action} template instead of the standard edit template. An empty value means edit both form and text, "form" means edit form only, "text" means edit text only |

=cut

sub edit {
    my $session = shift;
    my ( $text, $tmpl ) = init_edit( $session, 'edit' );
    finalize_edit ( $session, $text, $tmpl );
}


sub init_edit {
    my ( $session, $templateName )  = @_;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $user = $session->{user};

    # empty means edit both form and text, "form" means edit form only,
    # "text" means edit text only
    my $editaction = lc($query->param( 'action' )) || "";

    my $saveCmd = $query->param( 'cmd' ) || '';
    my $redirectTo = $query->param( 'redirectto' ) || '';
    my $onlyWikiName = TWiki::isTrue( $query->param( 'onlywikiname' ));
    my $onlyNewTopic = TWiki::isTrue( $query->param( 'onlynewtopic' ));
    my $formTemplate  = $query->param( 'formtemplate' ) || '';
    my $templateTopic = $query->param( 'templatetopic' ) || '';
    # apptype is undocumented legacy
    my $cgiAppType = $query->param( 'contenttype' ) ||
      $query->param( 'apptype' ) || 'text/html';
    my $skin = $session->getSkin();
    my $theParent = $query->param( 'topicparent' ) || '';
    my $ptext = $query->param( 'text' );
    my $store = $session->{store};

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'edit' );
    TWiki::UI::checkMirror( $session, $webName, $topic );

    my $tmpl = '';
    my $text = '';
    my $meta = '';
    my $extra = '';
    my $topicExists  = $store->topicExists( $webName, $topic );

    # If you want to edit, you have to be able to view and change.
    TWiki::UI::checkAccess( $session, $webName, $topic, 'view', $user );
    TWiki::UI::checkAccess( $session, $webName, $topic, 'change', $user );

    # Check lease, unless we have been instructed to ignore it
    # or if we are using the 10X's topic name for dynamic topic names
    my $breakLock = $query->param( 'breaklock' ) || '';
    unless( $breakLock || ($topic =~ /X{10}/ )) {
        my $lease = $store->getLease( $webName, $topic );
        if( $lease ) {
            my $who = $lease->{user}->webDotWikiName();

            if( $who ne $user->webDotWikiName() ) {
                # redirect; we are trying to break someone else's lease
                my( $future, $past );
                my $why = $lease->{message};
                my $def;
                my $t = time();
                if( $t > $lease->{expires} ) {
                    # The lease has expired, but see if we are still
                    # expected to issue a "less forceful' warning
                    if( $TWiki::cfg{LeaseLengthLessForceful} < 0 ||
                          $t < $lease->{expires} +
                            $TWiki::cfg{LeaseLengthLessForceful} ) {
                        $def = 'lease_old';
                        $past = TWiki::Time::formatDelta(
                            $t - $lease->{expires}, $session->{i18n} );
                        $future = '';
                    }
                }
                else {
                    # The lease is active
                    $def = 'lease_active';
                    $past = TWiki::Time::formatDelta(
                        $t - $lease->{taken}, $session->{i18n} );
                    $future = TWiki::Time::formatDelta(
                        $lease->{expires} - $t, $session->{i18n} );
                }
                if( $def ) {
                    # use a 'keep' redirect to ensure we pass parameter
                    # values in the query on to the oops script
                    throw TWiki::OopsException( 'leaseconflict',
                                                def => $def,
                                                web => $webName,
                                                topic => $topic,
                                                keep => 1,
                                                params =>
                                                  [ $who, $past, $future, 'edit' ] );
                }
            }
        }
    }

    # Prevent editing existing topic?
    if( $onlyNewTopic && $topicExists ) {
        # Topic exists and user requested oops if it exists
        throw TWiki::OopsException( 'attention',
                                    def => 'topic_exists',
                                    web => $webName,
                                    topic => $topic );
    }

    # prevent non-Wiki names?
    if( ( $onlyWikiName )
        && ( ! $topicExists )
        && ( ! TWiki::isValidTopicName( $topic ) ) ) {
         # do not allow non-wikinames
        throw TWiki::OopsException( 'attention',
                                    def => 'not_wikiword',
                                    web => $webName,
                                    topic => $topic,
                                    params => [ $topic ] );
    }

    if( $topicExists ) {
        ( $meta, $text ) =
          $store->readTopic( undef, $webName, $topic, undef );
    }

    if( $saveCmd && ! $session->{user}->isAdmin()) {
        throw TWiki::OopsException( 'accessdenied', def=>'only_group',
                                    web => $webName, topic => $topic,
                                    params => $TWiki::cfg{UsersWebName}.
                                    '.'.$TWiki::cfg{SuperAdminGroup} );
    }


    # Get edit template, standard or a different skin
    my $template = $query->param( 'template' ) ||
	$session->{prefs}->getPreferencesValue('EDIT_TEMPLATE') ||
        $templateName;
    $tmpl =
      $session->{templates}->readTemplate( $template.$editaction, $skin );

    if( !$tmpl && $template ne $templateName ) {
        $tmpl = $session->{templates}->readTemplate( $templateName, $skin );
    }

    if( !$tmpl ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'no_such_template',
                                    web => $webName,
                                    topic => $topic,
                                    params => [ $template.$editaction,
                                                'EDIT_TEMPLATE' ] );
    }

    my $templateWeb = $webName;
    unless( $topicExists ) {
        if( $templateTopic ) {
            ( $templateWeb, $templateTopic ) =
              $session->normalizeWebTopicName( $templateWeb, $templateTopic );

            unless( $store->topicExists( $templateWeb, $templateTopic )) {
                throw TWiki::OopsException( 'accessdenied',
                                            def => 'no_such_topic',
                                            web => $templateWeb,
                                            topic => $templateTopic,
                                            params => [ 'templatetopic' ] );
            }

            ( $meta, $text ) =
              $store->readTopic( $session->{user}, $templateWeb,
                                        $templateTopic, undef );
            $templateTopic = $templateWeb.'.'.$templateTopic;
        } else {
            ( $meta, $text ) = TWiki::UI::readTemplateTopic( $session, 'WebTopicEditTemplate' );
        }

        $extra = "(not exist)";

        # If present, instantiate form
        if( ! $formTemplate ) {
            my $form = $meta->get( 'FORM' );
            $formTemplate = $form->{name} if $form;
        }

        $text = $session->expandVariablesOnTopicCreation( $text, $user );
        $tmpl =~ s/%NEWTOPIC%/1/;
    } else {
        $tmpl =~ s/%NEWTOPIC%//;
    }
    $tmpl =~ s/%TEMPLATETOPIC%/$templateTopic/;
    $tmpl =~ s/%REDIRECTTO%/$redirectTo/;

    # override with parameter if set
    $text = $ptext if defined $ptext;

    # Insert the rev number/date we are editing. This will be boolean false if
    # this is a new topic.
    if( $topicExists ) {
        my ( $orgDate, $orgAuth, $orgRev ) = $meta->getRevisionInfo();
        $tmpl =~ s/%ORIGINALREV%/${orgRev}_$orgDate/g;
    } else {
        $tmpl =~ s/%ORIGINALREV%/0/g;
    }

    # parent setting
    if( $theParent eq 'none' ) {
        $meta->remove( 'TOPICPARENT' );
    } elsif( $theParent ) {
        my $parentWeb;
        ($parentWeb, $theParent) =
          $session->normalizeWebTopicName( $webName, $theParent );
        if( $parentWeb ne $webName ) {
            $theParent = $parentWeb.'.'.$theParent;
        }
        $meta->put( 'TOPICPARENT', { name => $theParent } );
    } else {
      $theParent = $meta->getParent();
    }
    $tmpl =~ s/%TOPICPARENT%/$theParent/;

    if( $formTemplate ) {
        $meta->remove( 'FORM' );
        if( $formTemplate ne 'none' ) {
            $meta->put( 'FORM', { name => $formTemplate } );
            # Because the form has been expanded from a Template, we
            # want to expand $percnt-style content right now
            $meta->forEachSelectedValue(qr/FIELD/,
                                        qr/value/,
                                        sub {TWiki::expandStandardEscapes(@_)},
                                    );
        } else {
            $meta->remove( 'FORM' );
        }
        $tmpl =~ s/%FORMTEMPLATE%/$formTemplate/go;
    }

    if( $saveCmd ) {
        $text = $store->readTopicRaw( $session->{user}, $webName,
                                                 $topic, undef );
    }

    $session->{plugins}->beforeEditHandler(
        $text, $topic, $webName, $meta ) unless( $saveCmd );

    if( $TWiki::cfg{Log}{edit} ) {
        # write log entry
        $session->writeLog( 'edit', $webName.'.'.$topic, $extra );
    }

    $tmpl =~ s/\(edit\)/\(edit cmd=$saveCmd\)/go if $saveCmd;

    $tmpl =~ s/%CMD%/$saveCmd/go;
    $session->enterContext( 'can_render_meta', $meta );

    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $webName, $topic );
    # Don't want to render form fields, so this after getRenderedVersion
    my $formMeta = $meta->get( 'FORM' );
    my $form = '';
    my $formText = '';
    $form = $formMeta->{name} if( $formMeta );
    if( $form && !$saveCmd ) {
        my $formDef = new TWiki::Form( $session, $templateWeb, $form );
        unless( $formDef ) {
            throw TWiki::OopsException( 'attention',
                                        def => 'no_form_def',
                                        web => $session->{webName},
                                        topic => $session->{topicName},
                                        params => [ $templateWeb, $form ] );
        }
        $formDef->getFieldValuesFromQuery( $session->{cgiQuery}, $meta );
        # And render them for editing
        # SMELL: these are both side-effecting functions, that will set
        # default values for fields if they are not set in the meta.
        # This behaviour really ought to be pulled out to a common place.
        if ( $editaction eq 'text' ) {
            $formText = $formDef->renderHidden( $meta );
        } else {
            $formText = $formDef->renderForEdit( $webName, $topic, $meta );
        }
    } elsif( !$saveCmd && $session->{prefs}->getWebPreferencesValue( 'WEBFORMS', $webName )) {
        $formText = $session->{templates}->readTemplate( "addform", $skin );
        $formText = $session->handleCommonTags( $formText, $webName, $topic );
    }
    $tmpl =~ s/%FORMFIELDS%/$formText/g;

    $tmpl =~ s/%FORMTEMPLATE%//go; # Clear if not being used

    return ( $text, $tmpl );
}

sub finalize_edit {

    my ( $session, $text, $tmpl ) = @_;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $user = $session->{user};
    # apptype is undocumented legacy
    my $cgiAppType = $query->param( 'contenttype' ) ||
      $query->param( 'apptype' ) || 'text/html';

    $tmpl =~ s/%UNENCODED_TEXT%/$text/g;

    $text = TWiki::entityEncode( $text );
    $tmpl =~ s/%TEXT%/$text/g;

    $session->{store}->setLease( $webName, $topic, $user, $TWiki::cfg{LeaseLength} );

    $session->writeCompletePage( $tmpl, 'edit', $cgiAppType );
}

1;
