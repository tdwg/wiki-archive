# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This Plugin publishes topics of a web as static HTML pages.

# =========================
package TWiki::Plugins::PublishWebPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName $debug
        $initializedi $error $publishWeb $publishSkin $exludeTopic $homeLabel
        $publishPath $attachPath $publishDir $attachDir
    );

$VERSION = '1.022';
$pluginName = 'PublishWebPlugin';  # Name of this Plugin
$initialized = 0;
$error = "";

# Hardcoded settings (change if needed)
$publishPath = "../static";       # output dir; must be relative to twiki/pub
$attachPath  = "_publish"; # attach dir; must be relative to $publishPath

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
$debug=1;

    writeDebug( "initPlugin( $web.$topic ) is OK" );
    $initialized = 0;
    $error = "";
    return 1;
}

sub initialize
{
    return if( $initialized );

    # Initialization
    $publishDir = TWiki::Func::getPubDir( ) . '/' . $publishPath;
    $attachDir  = $publishDir . '/' . $attachPath;

    # Get plugin preferences
    $publishWeb   = TWiki::Func::getPluginPreferencesValue( "PUBLISHWEBNAME" ) || "Publish";
    $publishSkin  = TWiki::Func::getPluginPreferencesValue( "PUBLISHSKIN" ) || "print";
    $excludeTopic = TWiki::Func::getPluginPreferencesValue( "EXCLUDETOPIC" ) || "";
    $excludeTopic =~ s/,\s*/\|/go;
    $excludeTopic = '(' . $excludeTopic . ')';
    $homeLabel    = TWiki::Func::getPluginPreferencesValue( "HOMELABEL" ) || "Home";

    $initialized = 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug( "commonTagsHandler( $_[2].$_[1] )" );
    $_[0] =~ s/%PUBLISHWEB{(.*?)}%/&handlePublish($1)/ge;
    $_[0] =~ s/%(START|STOP)PUBLISH%[\n\r]*//go;
}

# =========================
sub afterSaveHandler
{
### my ( $text, $topic, $web, $error ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug( "afterSaveHandler( $_[2].$_[1] )" );

    # This handler is called by TWiki::Store::saveTopic just after the save action.
    initialize();
    return unless( $_[2] eq $publishWeb );
    publishTopic( $_[2], $_[1], $_[0] );
}

# =========================
sub publishTopic
{
    my( $theWeb, $theTopic, $text ) = @_;

    writeDebug( "publishTopic( $theWeb, $theTopic )" );
    return unless( $theWeb eq $publishWeb );
    return if( $theTopic =~ /$excludeTopic/ );

    unless( $text ) {
        $text = TWiki::Func::readTopicText( $theWeb, $theTopic );
    }
    $text =~ s/%META:[A-Z0-9]+\{[^\n\r]+[\n\r]*//gs;
    $text =~ s/.*?%STARTPUBLISH%//s;
    $text =~ s/%STOPPUBLISH%.*//s;

    my $tmpl = TWiki::Func::readTemplate( "view", $publishSkin );
    $tmpl =~ s/%META\{.*?\}%[\n\r]*//gs;
    $tmpl =~ s/%TEXT%/$text/;

    my $saveWeb   = $web;    $web   = $theWeb;
    my $saveTopic = $topic;  $topic = $theTopic;
    $tmpl = TWiki::Func::expandCommonVariables( $tmpl, $topic, $web );
    ## FIXME my $wikiWordRegex = TWiki::Func::getRegularExpression( "wikiWordRegex" );
    $tmpl =~ s/(^|[\(\s])([A-Z][A-Za-z0-9]*)\.([A-Z]+[a-z]+[A-Za-z0-9])/$1<nop>$3/go;
    $tmpl =~ s/\[\[(.*?)\]\[(.*?)\]\]/&handleLink($1,$2)/geo;
    $tmpl =~ s/\[\[(.*?)\]\]/&handleLink($1,$1)/geo;
    $tmpl = TWiki::Func::renderText( $tmpl, $web );

    # fix links to attachments
    my $pubDir = TWiki::Func::getPubDir();
    my $pubUrl = TWiki::Func::getPubUrlPath();
    $tmpl =~ s/($pubUrl)\/([^'" ]+)/&fixAndCopyAttachments($1, $2, $pubDir )/geo;
    $tmpl =~ s/<\/?(nop|noautolink)\/?>\n?//gois;

    my $name = buildName( $topic, 'file' );
    writeDebug( "publishTopic, saving file $name using $publishSkin skin" );
    TWiki::Func::saveFile( $name, $tmpl );

    $web   = $saveWeb;
    $topic = $saveTopic;
    return $topic;
}

# =========================
sub fixAndCopyAttachments
{
    my ( $pubUrl, $path, $pubDir ) = @_;
    my $link = "/$attachPath/$path";
    my $file = $path;
    $file =~ s/.*\///;
    my $from = "$pubDir/$path";
    my $to   = "$attachDir/$file";
#    writeDebug( "fixAndCopyAttachments, copying attachment from $from to $to" );
    use File::Copy;
    unless( copy( $from, $to ) ) {
        $error = "Error: Can't copy $from $to ($!)";
        TWiki::Func::writeWarning( "- ${pluginName}: $error\n" );
    }
    #return "/$attachPath/$file"; ## RSP: 04/Oct/2006
    return "/twiki/static/_publish/$file";
}

# =========================
sub handleLink
{
    my ( $link, $label ) = @_;
    if( $link =~ /^(http|ftp)\:/ ) {
        return "<a href=\"$link\">$label</a>";
    } elsif( $link eq $label ) {
        return '<a href="'
               . buildName( $link, 'url' ) . '">'
               . buildName( $link, 'label' ) . '</a>';
    } else {
        return '<a href="' . buildName( $link, 'url' ) . "\">$label</a>";
    }
}

# =========================
sub handlePublish
{
    my ( $attr ) = @_;
    my $action = TWiki::Func::extractNameValuePair( $attr );
    my $text = '';
    initialize();
    if( $action eq "breadcrumb" ) {
        $text = '';
        if( $topic ne "Index" ) {
            $text .= "[[Index][$homeLabel]]";
            foreach( getParents( $web, $topic ) ) {
                $text .= " &gt; [[$_]["
                      . buildName( $_, 'label' ) . ']]';
            }
            $text .= ' &gt; ';
        }
    } elsif( $action eq "nicetopic" ) {
        $text =  buildName( $topic, 'label' );
    } elsif( $action eq "topicname" ) {
        $text =  buildName( $topic, 'link' );
    } elsif( $action eq "topicurl" ) {
        $text =  buildName( $topic, 'url' );
    } elsif( $action eq "publish" ) {
        my $topicName = TWiki::Func::extractNameValuePair( $attr, "topic" );
        if( $topicName eq "all" ) {
            my @topics = ();
            foreach( TWiki::Func::getTopicList( $publishWeb ) ) {
                $topicName = $_;
                if( publishTopic( $publishWeb, $topicName ) ) {
                    push( @topics, "[[$publishWeb.$topicName]]" );
                }
            }
            my $done = join( ', ', @topics );
            $text = "PUBLISHWEB: Published topics $done";
        } elsif( $topicName ) {
            if( TWiki::Func::topicExists( $publishWeb, $topicName ) ) {
                if( publishTopic( $publishWeb, $topicName ) ) {
                    $text = "PUBLISHWEB: Published topic [[$publishWeb.$topicName]]";
                } else {
                    $text = "PUBLISHWEB error: Topic [[$publishWeb.$topicName]] not published";
                }
            } else {
                $text = "PUBLISHWEB error: Topic <nop>$publishWeb.$topicName does not exist";
            }
        } else {
            $text = 'PUBLISHWEB error: Missing topic="" parameter for "publish" action';
        }
    } elsif( $action ) {
        $text = 'PUBLISHWEB error: Unrecognized action';
    } else {
        $text = '';
    }
    return $text;
}

# =========================
sub getParents
{
    my ( $web, $topic ) = @_;
    my @arr = ( );
    for(;;) {
        my $text = TWiki::Func::readTopicText( $web, $topic, '', 1 );
        last unless( $text =~ s/.*?\%META:TOPICPARENT\{name\=\"([^\"]+).*/$1/s );
        last if( $text =~ /^(Index|WebHome)$/ ); # stop at home topic
        last if( grep { /^$text$/ } @arr );      # prevent recursion
        push( @arr, $text );
        $topic = $text;
    }
    return @arr;
}

# =========================
sub buildName
{
    my ( $topic, $type ) = @_;
    # $type for 'Topic_Name':
    # 'name':   'topic_name.html'
    # 'url':    '/topic_name.html'
    # 'file':   '/file/path/to/topic_name.html'
    # 'label':  'Topic Name'
    my $text = lc( $topic ) . '.html';
    $text =~ s/[^a-z_\.]+//go;
    $text =~ /(.*)/;
    $text = $1; # untaint
    if( $type eq 'url' ) {
        #$text = '/' . $text; ## RSP 04/Oct/2006
        $text = $text; ## RSP 04/Oct/2006
    } elsif( $type eq 'file' ) {
        $text = $publishDir . '/' . $text; 
    } elsif( $type eq 'label' ) {
        $text = $topic;
        $text =~ s/_/ /go;
        $text =~ s/^Index$/$homeLabel/o;
    }
    return $text;
}

# =========================
sub writeDebug
{
    my( $text ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}: $text" ) if $debug;
}

# =========================

1;
