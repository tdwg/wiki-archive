# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006  TWiki Contributors.
# All Rights Reserved. TWiki Contributors are listed in the
# AUTHORS file in the root of this distribution.
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
# For licensing info read LICENSE file in the TWiki root.

# Still do to:
# Handle continuation lines (see Prefs::parseText). These should always
# go into a text area.

package TWiki::Plugins::PreferencesPlugin;

use strict;
use CGI ( -any );
use Error qw( :try );

use vars qw(
            $web $topic $user $installWeb $VERSION $RELEASE $pluginName
            $query @shelter
           );

# This should always be $Rev: 9839 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 9839 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

my $MARKER = "\007";

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    $pluginName = 'PreferencesPlugin';

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( 'Version mismatch between '.$pluginName.' and Plugins.pm' );
        return 0;
    }
    @shelter = ();

    return 1;
}

sub beforeCommonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;  
    return unless ( $_[0] =~ m/%EDITPREFERENCES{(.*?)}%/ );
    my $attrs = new TWiki::Attrs( $1 );
    my($formWeb, $form ) = TWiki::Func::normalizeWebTopicName( $web, $attrs->{_DEFAULT} );

    # SMELL: Unpublished API. No choice, though :-(
    my $formDef = new TWiki::Form( $TWiki::Plugins::SESSION, $formWeb, $form );

    $query = TWiki::Func::getCgiQuery();

    my $action = lc $query->param( 'prefsaction' );
    if ( $action eq 'edit' ) {
        TWiki::Func::setTopicEditLock( $web, $topic, 1 );

        $_[0] =~ s(^((?:\t|   )+\*\sSet\s)(\w+)\s\=(.*$(\n[ \t]+[^\s*].*$)*))
          ($1._generateEditField($web, $topic, $2, $3, $formDef))gem;
        $_[0] =~ s(%EDITPREFERENCES.*%)
          (_generateButtons($web, $topic, 0))eo;

    } elsif ( $action eq 'cancel' ) {
        TWiki::Func::setTopicEditLock( $web, $topic, 0 );
        my $url = TWiki::Func::getViewUrl( $web, $topic );
        TWiki::Func::redirectCgiQuery( $query, $url );
        return 0;

    } elsif ( $action eq 'save' ) {

        my $text = TWiki::Func::readTopicText( $web, $topic );
        $text =~ s(^((?:\t|   )+\*\sSet\s)(\w+)\s\=\s(.*)$)
          ($1._saveSet($web, $topic, $2, $3, $formDef))mgeo;

        my $error = TWiki::Func::saveTopicText( $web, $topic, $text, '' );
        TWiki::Func::setTopicEditLock( $web, $topic, 0 );
        my $url;
        if( $error ) {
            $url = $error;
        } else {
            $url = TWiki::Func::getViewUrl( $web, $topic );
        }
        TWiki::Func::redirectCgiQuery( $query, $url );
        return 0;

    } else {
        # implicit action="view"
        $_[0] =~ s(%EDITPREFERENCES.*%)
          (_generateButtons($web, $topic, 1))ge;
    }

    my $viewUrl = TWiki::Func::getScriptUrl( $web, $topic, 'viewauth', 0 );
    $_[0] = CGI::start_form(-name => 'editpreferences', -method => 'post',
                            -action => $viewUrl ).
                              $_[0].
                                CGI::end_form();
}

# Use the post-rendering handler to plug our formatted editor units
# into the text
sub postRenderingHandler {
    ### my ( $text ) = @_;

    $_[0] =~ s/SHELTER$MARKER(\d+)/$shelter[$1]/g;
}

# Pluck the default value of a named field from a form definition
sub _getField {
    my( $formDef, $name ) = @_;
    foreach my $f ( @{$formDef->{fields}} ) {
        if( $f->{name} eq $name ) {
            return $f;
        }
    }
    return undef;
}

# Generate a field suitable for editing this type. Use of the core
# function 'renderFieldForEdit' ensures that we will pick up
# extra edit types defined in other plugins.
sub _generateEditField {
    my( $web, $topic, $name, $value, $formDef ) = @_;
    $value =~ s/^\s*(.*?)\s*$/$1/ge;

    my $html;

    if( $formDef ) {
        my $fieldDef = _getField( $formDef, $name );
        if( $fieldDef ) {
            # SMELL: use of unpublished core function
            my $extras;
            ( $extras, $html ) =
              $formDef->renderFieldForEdit( $fieldDef, $web, $topic, $value);
        }
    }
    unless( $html ) {
        # No form definition, default to text field.
        $html = CGI::textfield( -class=>'twikiEditFormError', -name => $name,
                                 -size => 80, -value => $value );
    }

    push( @shelter, $html );

    return CGI::span({class=>'twikiAlert'},
                    $name.' = SHELTER'.$MARKER.$#shelter);
}

# Generate the buttons that replace the EDITPREFERENCES tag, depending
# on the mode
sub _generateButtons {
    my( $web, $topic, $doEdit ) = @_;

    my $text = '';
    if ( $doEdit ) {
        $text .= CGI::submit(-name=>'prefsaction', -value=>'Edit', -class=>'twikiButton');
    } else {
        $text .= CGI::submit(-name=>'prefsaction', -value=>'Save', -class=>'twikiSubmitButton');
        $text .= '&nbsp;&nbsp;';
        $text .= CGI::submit(-name=>'prefsaction', -value=>'Cancel', -class=>'twikiButton');
    }
    return $text;
}

# Given a Set in the topic being saved, look in the query to see
# if there is a new value for the Set and generate a new
# Set statement.
sub _saveSet {
    my( $web, $topic, $name, $value, $formDef ) = @_;

    my $newValue = $query->param( $name ) || $value;

    if( $formDef ) {
        my $fieldDef = _getField( $formDef, $name );
        my $type = $fieldDef->{type} || '';
        if( $type && $type =~ /^checkbox/ ) {
            my $val = '';
            my $vals = $fieldDef->{value};
            foreach my $item ( @$vals ) {
                my $cvalue = $query->param( $name.$item );
                if( defined( $cvalue ) ) {
                    if( ! $val ) {
                        $val = '';
                    } else {
                        $val .= ', ' if( $cvalue );
                    }
                    $val .= $item if( $cvalue );
                }
            }
            $newValue = $val;
        }
    }
    # if no form def, it's just treated as text

    return $name.' = '.$newValue;
}

1;
