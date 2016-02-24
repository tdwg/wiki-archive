# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
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

---+ package TWiki::Client::TemplateLogin

This is a login manager that you can specify in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It provides users with a
template-based form to enter usernames and passwords, and works with the
PasswordManager that you specify to verify those passwords.

Subclass of TWiki::Client; see that class for documentation of the
methods of this class.

=cut

package TWiki::Client::TemplateLogin;

use strict;
use Assert;
use TWiki::Client;

@TWiki::Client::TemplateLogin::ISA = ( 'TWiki::Client' );

sub new {
    my( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new($session), $class );
    $session->enterContext( 'can_login' );
    return $this;
}

# Triggered on auth fail
sub forceAuthentication {
    my $this = shift;
    my $twiki = $this->{twiki};

    unless( $twiki->inContext( 'authenticated' )) {
        my $query = $twiki->{cgiQuery};
        # Redirect with passthrough so we don't lose the original query params
        my $twiki = $this->{twiki};
        my $topic = $twiki->{topicName};
        my $web = $twiki->{webName};
        my $url = $twiki->getScriptUrl( 0, 'login', $web, $topic);
        $query->param( -name=>'origurl', -value=>$ENV{REQUEST_URI} );
        $twiki->redirect( $url, 1 );
        return 1;
    }
    return undef;
}

# Content of a login link
sub loginUrl {
    my $this = shift;
    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};
    my $query = $twiki->{cgiQuery};
    return $twiki->getScriptUrl( 0, 'login', $web, $topic,
                                 origurl => $ENV{REQUEST_URI} );
}

=pod

---++ ObjectMethod login( $query, $twiki )

If a login name and password have been passed in the query, it
validates these and if authentic, redirects to the original
script. If there is no username in the query or the username/password is
invalid (validate returns non-zero) then it prompts again.

The password handler is expected to return a perl true value if the password
is valid. This return value is stored in a session variable called
VALIDATION. This is so that password handlers can return extra information
about the user, such as a list of TWiki groups stored in a separate
database, that can then be displayed by referring to
%<nop>SESSION_VARIABLE{"VALIDATION"}%

=cut

sub login {
    my( $this, $query, $twikiSession ) = @_;
    my $twiki = $this->{twiki};

    my $origurl = $query->param( 'origurl' );
    my $loginName = $query->param( 'username' );
    my $loginPass = $query->param( 'password' );

    # Eat these so there's no risk of accidental passthrough
    $query->delete('origurl', 'username', 'password');

    my $tmpl = $twiki->{templates}->readTemplate(
        'login', $twiki->getSkin() );

    my $banner = $twiki->{templates}->expandTemplate( 'LOG_IN_BANNER' );
    my $note = '';
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};

    my $cgisession = $this->{cgisession};

    if( $cgisession && $cgisession->param( 'AUTHUSER' ) &&
          $loginName ne $cgisession->param( 'AUTHUSER' )) {
        $banner = $twiki->{templates}->expandTemplate( 'LOGGED_IN_BANNER' );
        $note = $twiki->{templates}->expandTemplate( 'NEW_USER_NOTE' );
    }

    if( $loginName ) {
        my $passwordHandler = $twiki->{users}->{passwords};
        my $validation = $passwordHandler->checkPassword( $loginName, $loginPass );

        if( $validation ) {
            $this->userLoggedIn( $loginName );
            $cgisession->param( 'VALIDATION', $validation ) if $cgisession;
            if( !$origurl || $origurl eq $query->url() ) {
                $origurl = $twiki->getScriptUrl( 0, 'view', $web, $topic );
            }
            # Redirect with passthrough
            $twikiSession->redirect($origurl, 1 );
            return;
        } else {
            $banner = $twiki->{templates}->expandTemplate('UNRECOGNISED_USER');
        }
    }

    # TODO: add JavaScript password encryption in the template
    # to use a template)
    $origurl ||= '';
    $tmpl =~ s/%ORIGURL%/$origurl/g;
    $tmpl =~ s/%BANNER%/$banner/g;
    $tmpl =~ s/%NOTE%/$note/g;

    $tmpl = $twiki->handleCommonTags( $tmpl, $web, $topic );
    $tmpl = $twiki->{renderer}->getRenderedVersion( $tmpl, '' );
    $tmpl =~ s/<nop>//g;
    $twiki->writePageHeader( $query );
    print $tmpl;
}

1;
