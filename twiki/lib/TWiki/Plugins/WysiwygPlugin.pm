# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package WysiwygPlugin

This plugin is responsible for translating TML to HTML before an edit starts
and translating the resultant HTML back into TML.
The flow of control is as follows:
   1 User hits "edit"
   2 if the skin is WYWIWYGPLUGIN_WYWIWYGSKIN, the beforeEditHandler
      filters the edit
   3 The 'edit' template is instantiated with all the js and css
   4 editor invokes view URL with the 'wysiwyg_edit=1' parameter to
     obtain the clean document
      * The earliest possible handler is implemented by the plugin in this
        mode. This handler formats the text and then saves it so the rest
        of twiki rendering can't do anything to it. At the end of rendering
        it drops the saved text back in.
   5 User edits
   6 editor saves by posting to 'save' with the 'wysiwyg_edit=1' parameter
   7 the beforeSaveHandler sees this and converts the HTML back to tml
Note: In the case of a new topic, you might expect to see the "create topic"
screen in the editor when it goesback to twiki for the topic content. This
doesn't happen because the earliest possible handler is called on the topic
content and not the template. The template is effectively ignored and a blank
document is sent to the editor.

Attachment uploads can be handled by URL requests from the editor to the TWiki
upload script. If these uploads are done in an IFRAME, then the redirect at
the end of the upload is done in the IFRAME and the user doesn't see the
upload screens. This avoids the need to add any scripts to the bin dir.

=cut

package TWiki::Plugins::WysiwygPlugin;

use CGI qw( -any );
use strict;
use TWiki::Func;

use vars qw( $VERSION $RELEASE $MODERN $SKIN $SHORTDESCRIPTION );
use vars qw( $html2tml $tml2html $recursionBlock $imgMap $cairoCalled );
use vars qw( %TWikiCompatibility @refs );

$SHORTDESCRIPTION = 'Translator framework for Wysiwyg editors';

$VERSION = '$Rev: 12422 $';

$RELEASE = 'Dakar';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    if( defined( &TWiki::Func::normalizeWebTopicName )) {
        $MODERN = 1;
    } else {
        # SMELL: nasty global var needed for Cairo
        $cairoCalled = 0;
    }

    $SKIN = TWiki::Func::getPreferencesValue( 'WYSIWYGPLUGIN_WYSIWYGSKIN' );

    # %OWEB%.%OTOPIC% is the topic where the initial content should be
    # grabbed from, as defined in templates/edit.skin.tmpl
    TWiki::Func::registerTagHandler('OWEB',\&_OWEBTAG);
    TWiki::Func::registerTagHandler('OTOPIC',\&_OTOPICTAG);
    TWiki::Func::registerTagHandler('WYSIWYG_TEXT',\&_WYSIWYG_TEXT);
    TWiki::Func::registerTagHandler('JAVASCRIPT_TEXT',\&_JAVASCRIPT_TEXT);

    # Plugin correctly initialized
    return 1;
}

sub _OWEBTAG {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $query = TWiki::Func::getCgiQuery();

    return "$theWeb" unless $query;

    if(defined($query->param('templatetopic'))) {
        my @split=split(/\./,$query->param('templatetopic'));

	if($#split==0) {
	  return $theWeb;
	} else {
	  return $split[0];
	}
    }

    return $theWeb;
}

sub _OTOPICTAG {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $query = TWiki::Func::getCgiQuery();

    return "$theTopic" unless $query;

    if(defined($query->param('templatetopic'))) {
        my @split=split(/\./,$query->param('templatetopic'));

	return $split[$#split];
    }

    return $theTopic;
}

# This handler is used to determine whether the topic is editable by
# Wysiwyg or not. The only thing it does is to redirect to a normal edit
# url if the skin is set to $SKIN and nasty content is found.
sub beforeEditHandler {
    #my( $text, $topic, $web, $meta ) = @_;
    return unless $SKIN;

    if( TWiki::Func::getSkin() =~ /\b$SKIN\b/o ) {
        my $exclusions = TWiki::Func::getPreferencesValue(
            'WYSIWYG_EXCLUDE' );
        my $calls_ok = TWiki::Func::getPreferencesValue(
            'WYSIWYG_EDITABLE_CALLS' );
        return unless $exclusions;
        my $not_ok = 0;
        if( $exclusions =~ /calls/
              && $_[0] =~ /%((?!($calls_ok){)[A-Z_]+{.*?})%/s ) {
            #print STDERR "WYSIWYG_DEBUG: has calls $1\n";
            $not_ok = 1;
        }
        if( $exclusions =~ /variables/ && $_[0] =~ /%([A-Z_]+)%/s ) {
            #print STDERR "$exclusions WYSIWYG_DEBUG: has variables $1\n";
            $not_ok = 1;
        }
        if( $exclusions =~ /html/ &&
              $_[0] =~ /<\/?((?!literal|verbatim|noautolink|nop|br)\w+)/ ) {
            #print STDERR "WYSIWYG_DEBUG: has html: $1\n";
            $not_ok = 1;
        }
        if( $exclusions =~ /comments/ && $_[0] =~ /<[!]--/ ) {
            #print STDERR "WYSIWYG_DEBUG: has comments\n";
            $not_ok = 1;
        }
        if( $exclusions =~ /pre/ && $_[0] =~ /<pre\w/ ) {
            #print STDERR "WYSIWYG_DEBUG: has pre\n";
            $not_ok = 1;
        }

        if( $not_ok ) {
            # redirect
            my $query = TWiki::Func::getCgiQuery();
            foreach my $p qw( skin cover ) {
                my $arg = $query->param( $p );
                if( $arg && $arg =~ s/\b$SKIN\b//o ) {
                    if( $arg =~ /^[\s,]*$/ ) {
                        $query->delete( $p );
                    } else {
                        $query->param( -name=>$p, -value=>$arg );
                    }
                }
            }
            my $url = $query->url( -full=>1, -path=>1, -query=>1 );
            TWiki::Func::redirectCgiQuery( $query, $url );
            # Bring this session to an untimely end
            exit 0;
        }
    }
}

# Invoked when the selected skin is in use to convert HTML to
# TML (best offorts)
sub beforeSaveHandler {
    #my( $text, $topic, $web ) = @_;
    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' ));

    unless( $html2tml ) {
        require TWiki::Plugins::WysiwygPlugin::HTML2TML;

        $html2tml = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    }

    my @rescue;

    # SMELL: really, really bad smell; bloody core should NOT pass text
    # with embedded meta to plugins! It is VERY BAD DESIGN!!!
    $_[0] =~ s/^(%META:[A-Z]+{.*?}%)\s*$/push(@rescue,$1);'<!--META_'.
      scalar(@rescue).'_META-->'/gem;

    unless( $MODERN ) {
        # undo the munging that has already been done (grrrrrrrrrr!!!!)
        $_[0] =~ s/\t/   /g;
    }

    my $opts = {
        web => $_[2],
        topic => $_[1],
        convertImage => \&convertImage,
        rewriteURL => \&postConvertURL,
        very_clean => 1, # aggressively polish saved HTML
    };

    # Let's just set this and see what happens....
    $opts->{very_clean} = 1;

    $_[0] = $html2tml->convert( $_[0], $opts );

    unless( $MODERN ) {
        # redo the munging
        $_[0] =~ s/   /\t/g;
    }

    $_[0] =~ s/\n<!--META_(\d+)_META-->/\n$rescue[$1-1]/gs;
    # Add a newline if one has been eaten
    $_[0] =~ s/<!--META_(\d+)_META-->/\n$rescue[$1-1]/g;
}

# Handler used to process text in a =view= URL to generate text/html
# containing the HTML of the topic to be edited.
#
# Invoked when the selected skin is in use to convert the text to HTML
# We can't use the beforeEditHandler, because the editor loads up and then
# uses a URL to fetch the text to be edited. This handler is designed to
# provide the text for that request. It's a real struggle, because the
# commonTagsHandler is called so many times that getting the right
# call is hard, and then preventing a repeat call is harder!
sub beforeCommonTagsHandler {
    #my ( $text, $topic, $web )
    return if $recursionBlock;
    if( $MODERN ) {
        return unless TWiki::Func::getContext()->{body_text};
    } else {
        # DANGEROUS SMELL: only way to tell what we are processing is
        # the order of the calls to commonTagsHandler - the first call after
        # initPlugin is the body text in Cairo. We only want to process the
        # body text.
        return if( $cairoCalled );
        $cairoCalled = 1;
    }

    my $query = TWiki::Func::getCgiQuery();

    return unless $query;

    return unless defined( $query->param( 'wysiwyg_edit' ));

    # stop it from processing the template without expanded
    # %TEXT% (grr; we need a better way to tell where we
    # are in the processing pipeline)
    return if( $_[0] =~ /^<!-- WysiwygPlugin Template/ );

    # Have to re-read the topic because verbatim blocks have already been
    # lifted out, and we need them.
    my $topic = $_[1];
    my $web = $_[2];
    my( $meta, $text );
    my $altText = $query->param( 'templatetopic' );
    if( $altText && TWiki::Func::topicExists( $web, $altText )) {
        ( $web, $topic ) = TWiki::Func::normalizeWebTopicName( $web, $altText );
    }

    $_[0] = _WYSIWYG_TEXT($TWiki::Plugins::SESSION, {}, $topic, $web);
}

# Handler used by editors that require pre-prepared HTML embedded in the
# edit template.
sub _WYSIWYG_TEXT {
    my ($session, $params, $topic, $web) = @_;

    # Have to re-read the topic because content has already been munged
    # by other plugins, or by the extraction of verbatim blocks.
    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    # Translate the topic text to pure HTML.
    unless( $tml2html ) {
        require TWiki::Plugins::WysiwygPlugin::TML2HTML;
        $tml2html = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    }
    $text = $tml2html->convert(
        $text,
        {
            web => $web,
            topic => $topic,
            getViewUrl => \&getViewUrl,
            expandVarsInURL => \&expandVarsInURL,
        }
       );

    # Lift out the text to protect it from further TWiki rendering. It will be
    # put back in the postRenderingHandler.
    return _liftOut( $text );
}

# Handler used to present the editable text in a javascript constant string
sub _JAVASCRIPT_TEXT {
    my ($session, $params, $topic, $web) = @_;

    my $html = _dropBack( _WYSIWYG_TEXT( @_ ));

    $html =~ s/([\\'])/\\$1/sg;
    $html =~ s/\r/\\r/sg;
    $html =~ s/\n/\\n/sg;
    $html =~ s/script/scri'+'pt/g;

    return _liftOut( "'$html'" );
}

# DEPRECATED in Dakar (postRenderingHandler does the job better)
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler {
    return postRenderingHandler( @_ );
}

# Dakar handler, replaces endRenderingHandler above
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
sub postRenderingHandler {
    return if( $recursionBlock || !$tml2html );

    # Replace protected content.
    $_[0] = _dropBack($_[0]);
}

# Commented out because of Bugs:Item1176
# DEPRECATED in Dakar (modifyHeaderHandler does the job better)
#$TWikiCompatibility{writeHeaderHandler} = 1.1;
#sub writeHeaderHandler {
#    my $query = shift;
#    if( $query->param( 'wysiwyg_edit' )) {
#        return "Expires: 0\nCache-control: max-age=0, must-revalidate";
#    }
#    return '';
#}

# Dakar modify headers.
sub modifyHeaderHandler {
    my( $headers, $query ) = @_;

    if( $query->param( 'wysiwyg_edit' )) {
        $headers->{Expires} = 0;
        $headers->{'Cache-control'} = 'max-age=0, must-revalidate';
    }
}

# callback passed to the TML2HTML convertor
sub getViewUrl {
    my( $web, $topic ) = @_;

    # the Cairo documentation says getViewUrl defaults the web. It doesn't.
    unless( defined $TWiki::Plugins::SESSION ) {
        $web ||= $TWiki::webName;
    }

    return TWiki::Func::getViewUrl( $web, $topic );
}

# The subset of vars for which bidirection transformation is supported
# in URLs only
use vars qw( @VARS );

# The set of variables that get "special treatment" in URLs
@VARS = (
    '%ATTACHURL%',
    '%ATTACHURLPATH%',
    '%PUBURL%',
    '%PUBURLPATH%',
    '%SCRIPTURLPATH{"view"}%',
    '%SCRIPTURLPATH%',
    '%SCRIPTURL{"view"}%',
    '%SCRIPTURL%',
    '%SCRIPTSUFFIX%', # bit dodgy, this one
   );

# Initialises the mapping from var to URL and back
sub _populateVars {
    my $opts = shift;

    return if( $opts->{exp} );

    local $recursionBlock = 1; # block calls to beforeCommonTagshandler

    my @exp = split(
        /\0/, TWiki::Func::expandCommonVariables(
            join("\0", @VARS), $opts->{topic}, $opts->{web} ));

    for my $i (0..$#VARS) {
        my $nvar = $VARS[$i];
        if($opts->{markvars}) {
            # SMELL: this is clunky.... but the markvars transformation has
            # already happened by the time this is used.
            $nvar =~ s/^%(.*)%$/CGI::span({class=>"TMLvariable"}, $1)/e;
        }
        $opts->{match}[$i] = $nvar;
        $exp[$i] ||= '';
    }
    $opts->{exp} = \@exp;
}

# callback passed to the TML2HTML convertor on each
# variable in a URL used in a square bracketed link
sub expandVarsInURL {
    my( $url, $opts ) = @_;

    return '' unless $url;

    _populateVars( $opts );
    for my $i (0..$#VARS) {
        $url =~ s/$opts->{match}[$i]/$opts->{exp}->[$i]/g;
    }
    return $url;
}

# callback passed to the HTML2TML convertor
sub postConvertURL {
    my( $url, $opts ) = @_;
    #my $orig = $url; #debug

    local $recursionBlock = 1; # block calls to beforeCommonTagshandler

    my $anchor = '';
    if( $url =~ s/(#.*)$// ) {
        $anchor = $1;
    }
    my $parameters = '';
    if( $url =~ s/(\?.*)$// ) {
        $parameters = $1;
    }

    _populateVars( $opts );

    for my $i (0..$#VARS) {
        next unless $opts->{exp}->[$i];
        $url =~ s/^$opts->{exp}->[$i]/$VARS[$i]/;
    }

    if ($url =~ m#^%SCRIPTURL(?:PATH)?(?:{"view"}%|%/view[^/]*)/(\w+)(?:/(\w+))?$# && !$parameters) {
        my( $web, $topic );

        if( $2 ) {
            ($web, $topic) = ($1, $2);
        } else {
            $topic = $1;
        }

        if( $web && $web ne $opts->{web} ) {
            #print STDERR "$orig -> $web.$topic$anchor\n"; #debug
            return $web.'.'.$topic.$anchor;
        }
        #print STDERR "$orig -> $topic$anchor\n"; #debug
        return $topic.$anchor;
    }

    #print STDERR "$orig -> $url$anchor$parameters\n"; #debug
    return $url.$anchor.$parameters;
}

# callback used to convert an image reference into a TWiki variable
# callback passed to the HTML2TML convertor
sub convertImage {
    my( $x, $opts ) = @_;

    return undef unless $x;

    local $recursionBlock = 1; # block calls to beforeCommonTagshandler

    unless( $imgMap ) {
        $imgMap = {};
        my $imgs =
          TWiki::Func::getPreferencesValue( 'WYSIWYGPLUGIN_ICONS' );
        if( $imgs ) {
            while( $imgs =~ s/src="(.*?)" alt="(.*?)"// ) {
                my( $src, $alt ) = ( $1, $2 );
                $src = TWiki::Func::expandCommonVariables(
                    $src, $opts->{topic}, $opts->{web} );
                $alt .= '%' if $alt =~ /^%/;
                $imgMap->{$src} = $alt;
            }
        }
    }

    return $imgMap->{$x};
}

# Replace content with a marker to prevent it being munged by TWiki
sub _liftOut {
    my( $text ) = @_;
    my $n = scalar( @refs );
    push( @refs, $text );
    return "\05$n\05";
}

# Substitute marker
sub _dropBack {
    my( $text) = @_;
    # Restore everything that was lifted out
    while( $text =~ s/\05([0-9]+)\05/$refs[$1]/gi ) {
    }
    return $text;
}

1;
