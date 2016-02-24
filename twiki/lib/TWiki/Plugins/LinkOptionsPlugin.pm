# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2005 Aurelio A. Heckert, aurium@gmail.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::LinkOptionsPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug
    );

# This should always be $Rev: 11207 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11207 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'LinkOptionsPlugin';  # Name of this Plugin

$numLastWinWithoutName = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/\[\[([^]\n]+)\]\[([^]\n]+)\]\[([^]]+)\]\]/&handleLinkOptions($1, $2, $3)/ge;
}

# =========================

@preDefOptions = (
  'newwin',
  'name',
  'title',
  'class',
  'id',
  'skin'
);
@winOptions = (
  'directories',
  'location',
  'menubar',
  'resizable',
  'scrollbars',
  'status',
  'titlebar',
  'toolbar'
);

sub handleLinkOptions
{
  my ( $link, $text, $options ) = @_;
  my %extraOpts = ();
  my $style = '';
  my $extraAtt = '';
  my @sepOpt;
  
  my $html = TWiki::Func::renderText("[[$link][$text]]");
  
  $options =~ s/win([^:|]+):([^|]+)(\||$)/$1=:$2$3/g;
  my @options = split(/\|/, $options);
  foreach $option (@options){
    @sepOpt = split(/:/, $option);
    if ( in_array(lc($sepOpt[0]), @preDefOptions)
      || in_array(lc($sepOpt[0]), @winOptions) ){
      $extraOpts{lc($sepOpt[0])} = $sepOpt[1];
    }
    else{
      $style .= "$option; ";
    }
  }
  
  if ( $extraOpts{'skin'} ){
    if ( $html =~ m/^<a [^>]*href="[^"]*\?[^"]*skin=.+/ ){
      $html =~ s/^<a ([^>]*href="[^"]*\?[^"]*skin=)[^&"]*(.+)/<a $1$extraOpts{'skin'}$2/;  #"
    } else {
      if ( $html =~ m/^<a [^>]*href="[^"]*\?.+/ ){
        $html =~ s/^<a ([^>]*href="[^"]*\?)(.+)/<a $1skin=$extraOpts{'skin'}&$2/;  #"
      } else {
        $html =~ s/^<a ([^>]*href="[^"]*)"(.+)/<a $1?skin=$extraOpts{'skin'}"$2/;  #"
      }
    }
  }
  
  my $URL = getByER($html, ' href="([^"]*)"', 1);
  
  if ( $extraOpts{'newwin'} ){
    if ( !$extraOpts{'name'} ){
      $numLastWinWithoutName++;
      $extraOpts{'name'} = "winNumber$numLastWinWithoutName";
    }
    $winWidth = getByER( $extraOpts{'newwin'}, '(.+)x.+', 1);
    $winHeight = getByER( $extraOpts{'newwin'}, '.+x(.+)', 1);
    $extraAtt .= " onclick=\"open('$URL', '". $extraOpts{'name'} ."', '";
    # The defaults for the new window:
    $extraOpts{'directories'} = 0 if ! defined $extraOpts{'directories'};
    $extraOpts{'location'} = 0    if ! defined $extraOpts{'location'};
    $extraOpts{'toolbar'} = 0     if ! defined $extraOpts{'toolbar'};
    $extraOpts{'menubar'} = 0     if ! defined $extraOpts{'menubar'};
    $extraOpts{'resizable'} = 1   if ! defined $extraOpts{'resizable'};
    $extraOpts{'scrollbars'} = 1  if ! defined $extraOpts{'scrollbars'};
    $extraOpts{'status'} = 1      if ! defined $extraOpts{'status'};
    $extraOpts{'titlebar'} = 1    if ! defined $extraOpts{'titlebar'};
    foreach $option ( @winOptions ){
      if ( defined $extraOpts{$option} ){
        $extraAtt .= $option.'='.$extraOpts{$option}.',';
      }
    }
    $extraAtt .= "width=$winWidth,height=$winHeight";
    $extraAtt .= "'); return false;\"";
  }
  
  if ( !$extraOpts{'newwin'} && $extraOpts{'name'} ){
    $html =~ s/^<a ([^>]*)target="[^"]*"([^>]*)>(.+)/<a $1$2>$3/;  #"
    $html =~ s/^<a (.+)/<a target="$extraOpts{'name'}" $1/;
  }
  
  if ( $extraOpts{'title'} ){
    if ( $html =~ m/^<a [^>]*title=.+/ ){
      $html =~ s/^<a ([^>]*)title="[^"]*"([^>]*)>(.+)/<a $1$2 title="$extraOpts{'title'}">$3/;  #"
    } else {
      $html =~ s/^<a ([^>]*)>(.+)/<a $1 title="$extraOpts{'title'}">$2/;
    }
  }
  if ( $extraOpts{'class'} ){
    if ( $html =~ m/^<a [^>]*title=.+/ ){
      $html =~ s/^<a ([^>]*)class="[^"]*"([^>]*)>(.+)/<a $1$2 class="$extraOpts{'class'}">$3/;  #"
    } else {
      $html =~ s/^<a ([^>]*)>(.+)/<a $1 class="$extraOpts{'class'}">$2/;
    }
  }
  if ( $extraOpts{'id'} ){
    if ( $html =~ m/^<a [^>]*id=.+/ ){
      $html =~ s/^<a ([^>]*)id="[^"]*"([^>]*)>(.+)/<a $1$2 id="$extraOpts{'id'}">$3/;  #"
    } else {
      $html =~ s/^<a ([^>]*)>(.+)/<a $1 id="$extraOpts{'id'}">$2/;
    }
  }
  
  
  $html =~ s/<a (.+)/<a $extraAtt style="$style" $1/;
  return $html;
}

# =========================

sub in_array {
  return if ($#_ < 1);
  my ($what, @where) = (@_);
  foreach (@where) {
    if ($_ eq $what) {
      return 1;
    }
  }
  return;
}

# =========================

sub getByER {
  my ( $str, $er, $numGrupo ) = @_;
  if ( $str =~ m/$er/ ){
    return ${$numGrupo};
  }
}

1;
