# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
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

=pod

---+ package TWiki::Render

This module provides most of the actual HTML rendering code in TWiki.

=cut

package TWiki::Render;

use strict;
use Assert;

# Use -any to force creation of functions for unrecognised tags, like del and ins,
# on earlier releases of CGI.pm (pre 2.79)
use CGI qw( -any );

use TWiki::Plurals ();
use TWiki::Attach ();
use TWiki::Attrs ();
use TWiki::Time ();

# Used to generate unique placeholders for when we lift blocks out of the
# text during rendering. 
use vars qw( $placeholderMarker );
$placeholderMarker = 0;

# defaults for trunctation of summary text
my $TMLTRUNC = 162;
my $PLAINTRUNC = 70;
my $MINTRUNC = 16;
# max number of lines in a summary (best to keep it even)
my $SUMMARYLINES = 6;

# limiting lookbehind and lookahead for wikiwords and emphasis
# use like \b
#SMELL: they really limit the number of places emphasis can happen.
my $STARTWW = qr/^|(?<=[\s\(])/m;
my $ENDWW = qr/$|(?=[\s,.;:!?)])/m;

BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=pod

---++ ClassMethod new ($session)

Creates a new renderer with initial state from preference values
(NEWTOPICBGCOLOR, NEWTOPICFONTCOLOR NEWTOPICLINKSYMBOL
 LINKTOOLTIPINFO)

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    $this->{session} = $session;

    $this->{NEWTOPICBGCOLOR} =
      $session->{prefs}->getPreferencesValue('NEWTOPICBGCOLOR')
        || '#FFFFCE';
    $this->{NEWTOPICFONTCOLOR} =
      $session->{prefs}->getPreferencesValue('NEWTOPICFONTCOLOR')
        || '#0000FF';
    $this->{NEWLINKSYMBOL} =
      $session->{prefs}->getPreferencesValue('NEWTOPICLINKSYMBOL')
        || CGI::sup('?');
    $this->{NEWLINKFORMAT} =
      $session->{prefs}->getPreferencesValue('NEWLINKFORMAT')
        || '<span class="twikiNewLink">$text<a href="%SCRIPTURLPATH{"edit"}%/$web/$topic?topicparent=%WEB%.%TOPIC%" '.
	   'rel="nofollow" title="%MAKETEXT{"Create this topic"}%">'.
           '$linksymbol</a></span>';
    # tooltip init
    $this->{LINKTOOLTIPINFO} =
      $session->{prefs}->getPreferencesValue('LINKTOOLTIPINFO')
        || '';
    $this->{LINKTOOLTIPINFO} = '$username - $date - r$rev: $summary'
      if( TWiki::isTrue( $this->{LINKTOOLTIPINFO} ));

    return $this;
}

=pod

---++ ObjectMethod renderParent($web, $topic, $meta, $params) -> $text

Render parent meta-data

=cut

sub renderParent {
    my( $this, $web, $topic, $meta, $ah ) = @_;
    my $dontRecurse = $ah->{dontrecurse} || 0;
    my $noWebHome =   $ah->{nowebhome} || 0;
    my $prefix =      $ah->{prefix} || '';
    my $suffix =      $ah->{suffix} || '';
    my $usesep =      $ah->{separator} || ' &gt; ';
    my $format =      $ah->{format} || '[[$web.$topic][$topic]]';

    return '' unless $web && $topic;

    my %visited;
    $visited{$web.'.'.$topic} = 1;

    my $pWeb = $web;
    my $pTopic;
    my $text = '';
    my $parentMeta = $meta->get( 'TOPICPARENT' );
    my $parent;
    my $store = $this->{session}->{store};

    $parent = $parentMeta->{name} if $parentMeta;

    my @stack;

    while( $parent ) {
        ( $pWeb, $pTopic ) =
          $this->{session}->normalizeWebTopicName( $pWeb, $parent );
        $parent = $pWeb.'.'.$pTopic;
        last if( $noWebHome &&
                 ( $pTopic eq $TWiki::cfg{HomeTopicName} ) ||
                 $visited{$parent} );
        $visited{$parent} = 1;
	$text = $format;
	$text =~ s/\$web/$pWeb/g;
	$text =~ s/\$topic/$pTopic/g;
        unshift( @stack, $text );
        last if $dontRecurse;
        $parent = $store->getTopicParent( $pWeb, $pTopic );
    }
    $text = join( $usesep, @stack );

    if( $text) {
        $text = $prefix.$text if ( $prefix );
        $text .= $suffix if ( $suffix );
    }

    return $text;
}

=pod

---++ ObjectMethod renderMoved($web, $topic, $meta, $params) -> $text

Render moved meta-data

=cut

sub renderMoved {
    my( $this, $web, $topic, $meta, $params ) = @_;
    my $text = '';
    my $moved = $meta->get( 'TOPICMOVED' );
    $web =~ s#\.#/#go;

    if( $moved ) {
        my( $fromWeb, $fromTopic ) =
          $this->{session}->normalizeWebTopicName( $web, $moved->{from} );
        my( $toWeb, $toTopic ) =
          $this->{session}->normalizeWebTopicName( $web, $moved->{to} );
        my $by = $moved->{by};
        my $u = $this->{session}->{users}->findUser( $by );
        $by = $u->webDotWikiName() if $u;
        my $date = TWiki::Time::formatTime( $moved->{date}, '', 'gmtime' );

        # Only allow put back if current web and topic match stored information
        my $putBack = '';
        if( $web eq $toWeb && $topic eq $toTopic ) {
            $putBack  = ' - '.
              CGI::a( { title=>($this->{session}->{i18n}->maketext(
                                  'Click to move topic back to previous location, with option to change references.')
                               ),
                        href => $this->{session}->getScriptUrl
                        ( 0, 'rename', $web, $topic,
                         newweb => $fromWeb,
                         newtopic => $fromTopic,
                         confirm => 'on',
                         nonwikiword => 'checked' ),
                        rel => 'nofollow'
                      },
                      $this->{session}->{i18n}->maketext('put it back') );
        }
        $text = CGI::i(
          $this->{session}->{i18n}->maketext("[_1] moved from [_2] on [_3] by [_4]",
                                             "<nop>$toWeb.<nop>$toTopic",
                                             "<nop>$fromWeb.<nop>$fromTopic",
                                             $date,
                                             $by)) . $putBack;
    }
    return $text;
}

=pod

---++ ObjectMethod renderFormField($web, $topic, $meta, $params) -> $text

Render meta-data for a single formfield

=cut

sub renderFormField {
    my( $this, $meta, $attrs ) = @_;
    my $text = '';
    my $name = $attrs->{name};
    $text = renderFormFieldArg( $meta, $name ) if( $name );
    my $newline = $attrs->{newline};
    if ( defined $newline ) {
      $newline =~ s/\$n/\n/gos;
    } else {
      $newline = "<br />";
    }
    my $bar = $attrs->{bar} || "&#124;";
    # change any new line character sequences to <br />
    $text =~ s/\r?\n/$newline/gos;
    # escape "|" to HTML entity
    $text =~ s/\|/$bar/gos;
    return $text;
}

# Add a list item, of the given type and indent depth. The list item may
# cause the opening or closing of lists currently being handled.
sub _addListItem {
    my( $this, $result, $theType, $theElement, $theIndent, $theOlType ) = @_;

    $theIndent =~ s/   /\t/g;
    my $depth = length( $theIndent );

    my $size = scalar( @{$this->{LIST}} );

    # The whitespaces either side of the tags are required for the
    # emphasis REs to work.
    if( $size < $depth ) {
        my $firstTime = 1;
        while( $size < $depth ) {
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
            $$result .= ' <'.$theElement.">\n" unless( $firstTime );
            $$result .= ' <'.$theType.">\n";
            $firstTime = 0;
            $size++;
        }
    } else {
        while( $size > $depth ) {
            my $tags = pop( @{$this->{LIST}} );
            $$result .= "\n</".$tags->{element}.'></'.$tags->{type}.'> ';
            $size--;
        }
        if( $size ) {
            $$result .= "\n</".$this->{LIST}->[$size-1]->{element}.'> ';
        } else {
            $$result .= "\n" if $$result;
        }
    }

    if ( $size ) {
        my $oldt = $this->{LIST}->[$size-1];
        if( $oldt->{type} ne $theType ) {
            $$result .= ' </'.$oldt->{type}.'><'.$theType.">\n";
            pop( @{$this->{LIST}} );
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
        }
    }
}

sub _emitTR {
    my ( $this, $thePre, $theRow, $insideTABLE ) = @_;

    unless( $insideTABLE ) {
        $thePre .=
          CGI::start_table({ class=>'twikiTable',
                             border => 1,
                             cellspacing => 0,
                             cellpadding => 0 });
    }

    $theRow =~ s/\t/   /g;  # change tabs to space
    $theRow =~ s/\s*$//;    # remove trailing spaces
    $theRow =~ s/(\|\|+)/$TWiki::TranslationToken.length($1).'|'/ge;  # calc COLSPAN
    my $cells = '';
    foreach( split( /\|/, $theRow ) ) {
        my @attr;

        # Avoid matching single columns
        if ( s/$TWiki::TranslationToken([0-9]+)//o ) {
            push( @attr, colspan => $1 );
        }
        s/^\s+$/ &nbsp; /;
        my( $l1, $l2 ) = ( 0, 0 );
        if( /^(\s*).*?(\s*)$/ ) {
            $l1 = length( $1 );
            $l2 = length( $2 );
        }
        if( $l1 >= 2 ) {
            if( $l2 <= 1 ) {
                push( @attr, align => 'right' );
            } else {
                push( @attr, align => 'center' );
            }
        }
        if( /^\s*\*(.*)\*\s*$/ ) {
            push( @attr, bgcolor => '#99CCCC' );
            $cells .= CGI::th( { @attr }, CGI::strong( " $1 " ))."\n";
        } else {
            $cells .= CGI::td( { @attr }, " $_ " )."\n";
        }
    }
    return $thePre.CGI::Tr( $cells );
}

sub _fixedFontText {
    my( $theText, $theDoBold ) = @_;
    # preserve white space, so replace it by '&nbsp; ' patterns
    $theText =~ s/\t/   /g;
    $theText =~ s|((?:[\s]{2})+)([^\s])|'&nbsp; ' x (length($1) / 2) . $2|eg;
    $theText = CGI::b( $theText ) if $theDoBold;
    return CGI::code( $theText );
}

# Build an HTML &lt;Hn> element with suitable anchor for linking from %<nop>TOC%
sub _makeAnchorHeading {
    my( $this, $text, $theLevel ) = @_;

    $text =~ s/^\s*(.*?)\s*$/$1/;

    # - Build '<nop><h1><a name='atext'></a> heading </h1>' markup
    # - Initial '<nop>' is needed to prevent subsequent matches.
    # - filter out $TWiki::regex{headerPatternNoTOC} ( '!!' and '%NOTOC%' )
    my $anchorName =       $this->makeAnchorName( $text, 0 );
    my $compatAnchorName = $this->makeAnchorName( $text, 1 );
    # filter '!!', '%NOTOC%'
    $text =~ s/$TWiki::regex{headerPatternNoTOC}//o;
    my $html = '<nop><h'.$theLevel.'>';
    $html .= CGI::a( { name=>$anchorName }, '' );
    $html .= CGI::a( { name=>$compatAnchorName }, '')
      if( $compatAnchorName ne $anchorName );
    $html .= ' '.$text.' </h'.$theLevel.'>';

    return $html;
}

=pod

---++ ObjectMethod makeAnchorName($anchorName, $compatibilityMode) -> $anchorName

   * =$anchorName= -
   * =$compatibilityMode= -

Build a valid HTML anchor name

=cut

sub makeAnchorName {
    my( $this, $anchorName, $compatibilityMode ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    if( !$compatibilityMode &&
          $anchorName =~ /^$TWiki::regex{anchorRegex}$/ ) {
        # accept, already valid -- just remove leading #
        return substr($anchorName, 1);
    }

    # strip out potential links so they don't get rendered.
    # remove double bracket link
    $anchorName =~ s/\s*\[\s*\[.*?\]\s*\[(.*?)\]\s*\]/$1/go;
    $anchorName =~ s/\s*\[\s*\[\s*(.*?)\s*\]\s*\]/$1/go;
    # add an _ before bare WikiWords
    $anchorName =~ s/($TWiki::regex{wikiWordRegex})/_$1/go;

    if( $compatibilityMode ) {
        # remove leading/trailing underscores first, allowing them to be
        # reintroduced
        $anchorName =~ s/^[\s\#\_]*//;
        $anchorName =~ s/[\s\_]*$//;
    }
    $anchorName =~ s/<[\/]?\w[^>]*>//gi;    # remove HTML tags
    $anchorName =~ s/\&\#?[a-zA-Z0-9]*;//g; # remove HTML entities
    $anchorName =~ s/\&//g;                 # remove &
    # filter TOC excludes if not at beginning
    $anchorName =~ s/^(.+?)\s*$TWiki::regex{headerPatternNoTOC}.*/$1/o;
    # filter '!!', '%NOTOC%'
    $anchorName =~ s/$TWiki::regex{headerPatternNoTOC}//o;

    # For most common alphabetic-only character encodings (i.e. iso-8859-*),
    # remove non-alpha characters 
    if( defined($TWiki::cfg{Site}{CharSet}) &&
          $TWiki::cfg{Site}{CharSet} =~ /^iso-?8859-?/i ) {
        $anchorName =~ s/[^$TWiki::regex{mixedAlphaNum}]+/_/g;
    }
    $anchorName =~ s/__+/_/g;           # remove excessive '_' chars
    if ( !$compatibilityMode ) {
        $anchorName =~ s/^[\s\#\_]*//;  # no leading space nor '#', '_'
    }
    $anchorName =~ s/^(.{32})(.*)$/$1/; # limit to 32 chars - FIXME: Use Unicode chars before truncate
    if ( !$compatibilityMode ) {
        $anchorName =~ s/[\s\_]*$//;    # no trailing space, nor '_'
    }

    # No need to encode 8-bit characters in anchor due to UTF-8 URL support

    return $anchorName;
}

# Returns =title='...'= tooltip info in case LINKTOOLTIPINFO perferences variable is set. 
# Warning: Slower performance if enabled.
sub _linkToolTipInfo {
    my( $this, $theWeb, $theTopic ) = @_;
    return '' unless( $this->{LINKTOOLTIPINFO} );
    return '' if( $this->{LINKTOOLTIPINFO} =~ /^off$/i );
    return '' unless( $this->{session}->inContext( 'view' ));

    # FIXME: This is slow, it can be improved by caching topic rev info and summary
    my $store = $this->{session}->{store};
    # SMELL: we ought not to have to fake this. Topic object model, please!!
    my $meta = new TWiki::Meta( $this->{session}, $theWeb, $theTopic );
    my( $date, $user, $rev ) = $meta->getRevisionInfo();
    my $text = $this->{LINKTOOLTIPINFO};
    $text =~ s/\$web/<nop>$theWeb/g;
    $text =~ s/\$topic/<nop>$theTopic/g;
    $text =~ s/\$rev/1.$rev/g;
    $text =~ s/\$date/TWiki::Time::formatTime( $date )/ge;
    $text =~ s/\$username/$user->login()/ge;       # 'jsmith'
    $text =~ s/\$wikiname/$user->wikiName()/ge;  # 'JohnSmith'
    $text =~ s/\$wikiusername/$user->webDotWikiName()/ge; # 'Main.JohnSmith'
    if( $text =~ /\$summary/ ) {
        my $summary = $store->readTopicRaw
          ( undef, $theWeb, $theTopic, undef );
        $summary = $this->makeTopicSummary( $summary, $theTopic, $theWeb );
        $summary =~ s/[\"\']//g;       # remove quotes (not allowed in title attribute)
        $text =~ s/\$summary/$summary/g;
    }
    return $text;
}

=pod

---++ ObjectMethod internalLink ( $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink, $doKeepWeb ) -> $html

Generate a link. 

Note: Topic names may be spaced out. Spaced out names are converted to <nop>WikWords,
for example, "spaced topic name" points to "SpacedTopicName".
   * =$theWeb= - the web containing the topic
   * =$theTopic= - the topic to be lunk
   * =$theLinkText= - text to use for the link
   * =$theAnchor= - the link anchor, if any
   * =$doLinkToMissingPages= - boolean: false means suppress link for non-existing pages
   * =$doKeepWeb= - boolean: true to keep web prefix (for non existing Web.TOPIC)

Called by _handleWikiWord and _handleSquareBracketedLink and by Func::internalLink

Calls _renderWikiWord, which in turn will use Plurals.pm to match fold plurals to equivalency with their singular form 

SMELL: why is this available to Func?

=cut

sub internalLink {
    my( $this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    # SMELL - shouldn't it be callable by TWiki::Func as well?

    #PN: Webname/Subweb/ -> Webname/Subweb
    $theWeb =~ s/\/\Z//o;

    if($theLinkText eq $theWeb) {
      $theLinkText =~ s/\//\./go;
    }

    #WebHome links to tother webs render as the WebName
    if (($theLinkText eq $TWiki::cfg{HomeTopicName}) && 
        ($theWeb ne $this->{session}->{webName})) {
            $theLinkText = $theWeb;
    }

    # Get rid of leading/trailing spaces in topic name
    $theTopic =~ s/^\s*//o;
    $theTopic =~ s/\s*$//o;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word. TODO: Try to turn this off,
    # avoiding spaces being stripped elsewhere
    $theTopic =~ s/^(.)/\U$1/;
    $theTopic =~ s/\s([$TWiki::regex{mixedAlphaNum}])/\U$1/go;

    # Add <nop> before WikiWord inside link text to prevent double links
    $theLinkText =~ s/(?<=[\s\(])([$TWiki::regex{upperAlpha}])/<nop>$1/go;

    return _renderWikiWord($this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb);
}

# TODO: this should be overridable by plugins.
sub _renderWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb) = @_;
    
    # added by RSP to resolve links to user WikiNames
    my $username = $this->{session}->{users}->{usermappingmanager}->lookupLoginName($theTopic);
    if ($username) {
	return _renderUserWikiName($this, $theWeb,
                                   $theTopic, $theLinkText, $theAnchor);
    }
    
    my $store = $this->{session}->{store};
    my $topicExists = $store->topicExists( $theWeb, $theTopic );

    my $singular = '';
    unless( $topicExists ) {
        # topic not found - try to singularise
        $singular = TWiki::Plurals::singularForm($theWeb, $theTopic);
        if( $singular ) {
            $topicExists = $store->topicExists( $theWeb, $singular );
            $theTopic = $singular if $topicExists;
        }
    }

    if( $topicExists) {
        return _renderExistingWikiWord($this, $theWeb,
                                       $theTopic, $theLinkText, $theAnchor);
    }
    if( $doLinkToMissingPages ) {
        # CDot: disabled until SuggestSingularNotPlural is resolved
        # if ($singular && $singular ne $theTopic) {
        #     #unshift( @topics, $singular);
        # }
        return _renderNonExistingWikiWord($this, $theWeb, $theTopic,
                                          $theLinkText);
    }
    if( $doKeepWeb ) {
        return $theWeb.'.'.$theLinkText;
    }

    return $theLinkText;
}

#
# added by RSP to resolve links to user WikiNames
#
sub _renderUserWikiName {
    my ($this, $web, $topic, $text, $anchor) = @_;

    my $currentWebHome = '';
    $currentWebHome = 'twikiCurrentWebHomeLink ' 
	if (($web eq $this->{session}->{webName}) &&
	    ($topic eq $TWiki::cfg{HomeTopicName} ));

    my $currentTopic = '';
    $currentTopic = 'twikiCurrentTopicLink ' 
	if (($web eq $this->{session}->{webName}) &&
	    ($topic eq $this->{session}->{topicName}));
    my @attrs;
    my $href = $TWiki::cfg{TdwgUserPageUrl}."$topic";
    my $tooltip = $this->_linkToolTipInfo( $web, $topic );
    push( @attrs, class => $currentTopic.$currentWebHome.'twikiAnchorLink', href => $href.'#'.$anchor );
    push( @attrs, title => $tooltip ) if( $tooltip );
    my $link = CGI::a( { @attrs }, $text );
    return $link;
}

sub _renderExistingWikiWord {
    my ($this, $web, $topic, $text, $anchor) = @_;

    my $currentWebHome = '';
    $currentWebHome = 'twikiCurrentWebHomeLink ' if (($web eq $this->{session}->{webName}) &&
                                      ($topic eq $TWiki::cfg{HomeTopicName} ));

    my $currentTopic = '';
    $currentTopic = 'twikiCurrentTopicLink ' if (($web eq $this->{session}->{webName}) &&
                                       ($topic eq $this->{session}->{topicName}));

    my @attrs;
    my $href = $this->{session}->getScriptUrl( 0, 'view', $web, $topic );
    if( $anchor ) {
        $anchor = $this->makeAnchorName( $anchor );
        push( @attrs, class => $currentTopic.$currentWebHome.'twikiAnchorLink', href => $href.'#'.$anchor );
    } else {
        push( @attrs, class => $currentTopic.$currentWebHome.'twikiLink', href => $href );
    }
    my $tooltip = $this->_linkToolTipInfo( $web, $topic );
    push( @attrs, title => $tooltip ) if( $tooltip );

    my $link = CGI::a( { @attrs }, $text );
    # When we pass the tooltip text to CGI::a it may contain
    # <nop>s, and CGI::a will convert the < to &lt;. This is a
    # basic problem with <nop>.
    $link =~ s/&lt;nop&gt;/<nop>/g;
    return $link;
}

sub _renderNonExistingWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText) = @_;

    my $ans = $this->{NEWLINKFORMAT};
    $ans =~ s/\$web/$theWeb/g;
    $ans =~ s/\$topic/$theTopic/g;
    $ans =~ s/\$text/$theLinkText/g;
    $ans =~ s/\$linksymbol/$this->{NEWLINKSYMBOL}/g;
    $ans = $this->{session}->handleCommonTags($ans, 
	$this->{session}{webName}, $this->{session}{topicName});
    return $ans;
}

# _handleWikiWord is called by the TWiki Render routine when it sees a 
# wiki word that needs linking.
# Handle the various link constructions. e.g.:
# WikiWord
# Web.WikiWord
# Web.WikiWord#anchor
#
# This routine adds missing parameters before passing off to internallink
sub _handleWikiWord {
    my ( $this, $theWeb, $web, $topic, $anchor ) = @_;

    my $linkIfAbsent = 1;
    my $keepWeb = 0;
    my $text;

    $web = $theWeb unless (defined($web));
    if( defined( $anchor )) {
        ASSERT(($anchor =~ m/\#.*/)) if DEBUG; # must include a hash.
    } else {
        $anchor = '' ;
    }

    if ( defined( $anchor ) ) {
        # 'Web.TopicName#anchor' or 'Web.ABBREV#anchor' link
        $text = $topic.$anchor;
    } else {
        $anchor = '';

        # 'Web.TopicName' or 'Web.ABBREV' link:
        if ( $topic eq $TWiki::cfg{HomeTopicName} &&
             $web ne $this->{session}->{webName} ) {
            $text = $web;
        } else {
            $text = $topic;
        }
    }

    # Allow spacing out, etc
    $text = $this->{session}->{plugins}->renderWikiWordHandler( $text ) || $text;

    # =$doKeepWeb= boolean: true to keep web prefix (for non existing Web.TOPIC)
    # (Necessary to leave "web part" of ABR.ABR.ABR intact if topic not found)
    $keepWeb = ( $topic =~ /^$TWiki::regex{abbrevRegex}$/o && $web ne $this->{session}->{webName} );

    # false means suppress link for non-existing pages
    $linkIfAbsent = ( $topic !~ /^$TWiki::regex{abbrevRegex}$/o );

    # SMELL - it seems $linkIfAbsent, $keepWeb are always inverses of each
    # other
    # TODO: check the spec of doKeepWeb vs $doLinkToMissingPages

    return $this->internalLink( $web, $topic, $text, $anchor,
                                $linkIfAbsent, $keepWeb );
}


# Handle SquareBracketed links mentioned on page $theWeb.$theTopic
# format: [[$text]]
# format: [[$link][$text]]
sub _handleSquareBracketedLink {
    my( $this, $web, $topic, $link, $text ) = @_;

    # Strip leading/trailing spaces
    $link =~ s/^\s+//;
    $link =~ s/\s+$//;

    # Explicit external [[$link][$text]]-style can be handled directly
    if( $link =~ m!^($TWiki::regex{linkProtocolPattern}\:|/)! ) {
        if (defined $text) {
            # [[][]] style - protect text:
            # Prevent automatic WikiWord or CAPWORD linking in explicit links
            $text =~ s/(?<=[\s\(])($TWiki::regex{wikiWordRegex}|[$TWiki::regex{upperAlpha}])/<nop>$1/go;
        }
        else {
            # [[]] style - take care for legacy:
            # Prepare special case of '[[URL#anchor display text]]' link
            if ( $link =~ /^(\S+)\s+(.*)$/ ) {
                # '[[URL#anchor display text]]' link:
                $link = $1;
                $text = $2;
                $text =~ s/(?<=[\s\(])($TWiki::regex{wikiWordRegex}|[$TWiki::regex{upperAlpha}])/<nop>$1/go;
            }
        }
        return $this->_externalLink( $link, $text );
    }

    $text ||= $link;

    # Extract '#anchor'
    # $link =~ s/(\#[a-zA-Z_0-9\-]*$)//;
    my $anchor = '';
    if( $link =~ s/($TWiki::regex{anchorRegex}$)// ) {
        $anchor = $1;
    }

    # filter out &any; entities (legacy)
    $link =~ s/\&[a-z]+\;//gi;
    # filter out &#123; entities (legacy)
    $link =~ s/\&\#[0-9]+\;//g;
    # Filter junk
    $link =~ s/$TWiki::cfg{NameFilter}+/ /g;
    # Capitalise first word
    $link =~ s/^(.)/\U$1/;
    # Collapse spaces and capitalise following letter
    $link =~ s/\s([$TWiki::regex{mixedAlphaNum}])/\U$1/go;
    # Get rid of remaining spaces, i.e. spaces in front of -'s and ('s
    $link =~ s/\s//go;

    $topic = $link if( $link );

    # Topic defaults to the current topic
    ($web, $topic) = $this->{session}->normalizeWebTopicName( $web, $topic );

    return $this->internalLink( $web, $topic, $text, $anchor, 1, undef );
}

# Handle an external link typed directly into text. If it's an image
# (as indicated by the file type), and no text is specified, then use
# an img tag, otherwise generate a link.
sub _externalLink {
    my( $this, $url, $text ) = @_;

    if( $url =~ /\.(gif|jpg|jpeg|png)$/i && !$text) {
        my $filename = $url;
        $filename =~ s@.*/([^/]*)@$1@go;
        return CGI::img( { src => $url, alt => $filename } );
    }
    my $opt = '';
    if( $url =~ /^urn:lsid:/i ) {
	$text = $url;
	$url = 'http://lsid.tdwg.org/summary/'.$url;

    } elsif( $url =~ /^mailto:/i ) {
        if( $TWiki::cfg{AntiSpam}{EmailPadding} ) {
            $url =~  s/(\@[\w\_\-\+]+)(\.)/$1$TWiki::cfg{AntiSpam}{EmailPadding}$2/;
            if ($text) {
                $text =~ s/(\@[\w\_\-\+]+)(\.)/$1$TWiki::cfg{AntiSpam}{EmailPadding}$2/;
            }
        }
        if( $TWiki::cfg{AntiSpam}{HideUserDetails} ) {
            # Much harder obfuscation scheme. For link text we only encode '@'
            # See also Item2928 and Item3430 before touching this
            $url =~ s/(\W)/'&#'.ord($1).';'/ge;
            if ($text) {
                $text =~ s/\@/'&#'.ord('@').';'/ge;
            }
        }
    } else {
        $opt = ' target="_top"';
    }
    $text ||= $url;
    # SMELL: Can't use CGI::a here, because it encodes ampersands in
    # the link, and those have already been encoded once in the
    # rendering loop (they are identified as "stand-alone"). One
    # encoding works; two is too many. None would be better for everyone!
    return '<a href="'.$url.'"'.$opt.'>'.$text.'</a>';
}

# Generate a "mailTo" link
sub _mailLink {
    my( $this, $text ) = @_;

    my $url = $text;
    $url = 'mailto:'.$url unless $url =~ /^mailto:/i;
    return $this->_externalLink( $url, $text );
}

=pod

---++ ObjectMethod renderFORMFIELD ( %params, $topic, $web ) -> $html

Returns the fully rendered expansion of a %FORMFIELD{}% tag.

=cut

sub renderFORMFIELD {
    my ( $this, $params, $topic, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    my $formField = $params->{_DEFAULT};
    my $formTopic = $params->{topic};
    my $altText   = $params->{alttext};
    my $default   = $params->{default};
    my $rev       = $params->{rev};
    my $format    = $params->{'format'};

    unless ( $format ) {
        # if null format explicitly set, return empty
        # SMELL: it's not clear what this does; the implication
        # is that it does something that violates TWiki tag syntax,
        # so I've had to comment it out....
        # return '' if ( $args =~ m/format\s*=/o);
        # Otherwise default to value
        $format = '$value';
    }

    my $formWeb;
    if ( $formTopic ) {
        if ($topic =~ /^([^.]+)\.([^.]+)/o) {
            ( $formWeb, $topic ) = ( $1, $2 );
        } else {
            # SMELL: Undocumented feature, 'web' parameter
            $formWeb = $params->{web};
        }
        $formWeb = $web unless $formWeb;
    } else {
        $formWeb = $web;
        $formTopic = $topic;
    }

    my $meta = $this->{ffCache}{$formWeb.'.'.$formTopic};
    my $store = $this->{session}->{store};
    unless ( $meta ) {
        my $dummyText;
        ( $meta, $dummyText ) =
          $store->readTopic( $this->{session}->{user}, $formWeb, $formTopic, $rev );
        $this->{ffCache}{$formWeb.'.'.$formTopic} = $meta;
    }

    my $text = '';
    my $found = 0;
    my $title = '';
    if ( $meta ) {
        my @fields = $meta->find( 'FIELD' );
        foreach my $field ( @fields ) {
            my $name = $field->{name};
            $title = $field->{title} || $name;
            if( $title eq $formField || $name eq $formField ) {
                $found = 1;
                my $value = $field->{value};

                if (length $value) {
                    $text = $format;   
                    $text =~ s/\$value/$value/go;
                } elsif ( defined $default ) {
                    $text = $default;
                }
                last; #one hit suffices
            }
        }
    }

    unless ( $found ) {
        $text = $altText || '';
    }

    $text =~ s/\$title/$title/go;

    return $text;
}

=pod

---++ ObjectMethod getRenderedVersion ( $text, $theWeb, $theTopic ) -> $html

The main rendering function.

=cut

sub getRenderedVersion {
    my( $this, $text, $theWeb, $theTopic ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    return '' unless $text;  # nothing to do

    $theTopic ||= $this->{session}->{topicName};
    $theWeb ||= $this->{session}->{webName};
    my $session = $this->{session};
    my $plugins = $session->{plugins};
    my $prefs = $session->{prefs};
    
    @{$this->{LIST}} = ();

    # Initial cleanup
    $text =~ s/\r//g;
    # whitespace before <! tag (if it is the first thing) is illegal
    $text =~ s/^\s+(<![a-z])/$1/i;

    # clutch to enforce correct rendering at end of doc
    $text =~ s/\n?$/\n<nop>\n/s;

    # Maps of placeholders to tag parameters and text
    my $removed = {};
    my $removedComments = {};
    my $removedScript = {};
    my $removedHead = {};
    my $removedVerbatim = {};
    my $removedLiterals = {};

    $text = $this->takeOutBlocks( $text, 'literal', $removedLiterals );
    $text = $this->takeOutBlocks( $text, 'verbatim', $removedVerbatim );

    $text = $this->takeOutProtected( $text, qr/<\?([^?]*)\?>/s,
                                     $removedComments );
    $text = $this->takeOutProtected( $text, qr/<!DOCTYPE([^<>]*)>?/mi,
                                     $removedComments );
    $text = $this->takeOutProtected( $text, qr/<head.*?<\/head>/si,
                                     $removedHead );
    $text = $this->takeOutProtected( $text, qr/<script\b.*?<\/script>/si,
                                     $removedScript );

    # DEPRECATED startRenderingHandler before PRE removed
    # SMELL: could parse more efficiently if this wasn't
    # here.
    $plugins->startRenderingHandler( $text, $theWeb, $theTopic );

    $text = $this->takeOutBlocks( $text, 'pre', $removed );

    # Join lines ending in '\' (don't need \r?, it was removed already)
    $text =~ s/\\\n//gs;

    $plugins->preRenderingHandler( $text, $removed );

    if( $plugins->haveHandlerFor( 'insidePREHandler' )) {
        foreach my $region ( sort keys %$removed ) {
            next unless ( $region =~ /^pre\d+$/i );
            my @lines = split( /\r?\n/, $removed->{$region}{text} );
            my $rt = '';
            while ( scalar( @lines )) {
                my $line = shift( @lines );
                $plugins->insidePREHandler( $line );
                if ( $line =~ /\n/ ) {
                    unshift( @lines, split( /\r?\n/, $line ));
                    next;
                }
                $rt .= $line."\n";
            }
            $removed->{$region}{text} = $rt;
        }
    }

    if( $plugins->haveHandlerFor( 'outsidePREHandler' )) {
        # DEPRECATED - this is the one call preventing
        # effective optimisation of the TWiki ML processing loop,
        # as it exposes the concept of a 'line loop' to plugins,
        # but HTML is not a line-oriented language (though TML is).
        # But without it, a lot of processing could be moved
        # outside the line loop.
        my @lines = split( /\r?\n/, $text );
        my $rt = '';
        while ( scalar( @lines ) ) {
            my $line = shift( @lines );
            $plugins->outsidePREHandler( $line );
            if ( $line =~ /\n/ ) {
                unshift( @lines, split( /\r?\n/, $line ));
                next;
            }
            $rt .= $line . "\n";
        }

        $text = $rt;
    }

    # Escape rendering: Change ' !AnyWord' to ' <nop>AnyWord',
    # for final ' AnyWord' output
    $text =~ s/$STARTWW\!(?=[\w\*\=])/<nop>/gm;

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~ s/^>(.*?)$/'&gt;'.CGI::cite( $1 ).CGI::br()/gem;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$TWiki::TranslationToken!--/g;
    $text =~ s/-->/--}$TWiki::TranslationToken/g;
    # SMELL: this next fragment does not handle the case where HTML tags
    # are embedded in the values provided to other tags. The only way to
    # do this correctly is to parse the HTML (bleagh!). So we just assume
    # they have been escaped.
    $text =~ s/<(\/?\w+(:\w+)?)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
    $text =~ s/<(\w+(:\w+)?(\s+.*?|\/)?)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
    # XML processing instruction only valid at start of text
    $text =~ s/^<(\?\w.*?\?)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;

    # entitify lone < and >, praying that we haven't screwed up :-(
    $text =~ s/</&lt\;/g;
    $text =~ s/>/&gt\;/g;
    $text =~ s/{$TWiki::TranslationToken/</go;
    $text =~ s/}$TWiki::TranslationToken/>/go;

    # standard URI
    $text =~ s/(^|[-*\s(|])($TWiki::regex{linkProtocolPattern}:([^\s<>"]+[^\s*.,!?;:)<|]))/$1.$this->_externalLink($2)/geo;

    # other entities
    $text =~ s/&(\w+);/$TWiki::TranslationToken$1;/g;      # "&abc;"
    $text =~ s/&(#[0-9]+);/$TWiki::TranslationToken$1;/g;  # "&#123;"
    $text =~ s/&/&amp;/g;                         # escape standalone "&"
    $text =~ s/$TWiki::TranslationToken(#[0-9]+;)/&$1/go;
    $text =~ s/$TWiki::TranslationToken(\w+;)/&$1/go;

    # Headings
    # '<h6>...</h6>' HTML rule
    $text =~ s/$TWiki::regex{headerPatternHt}/$this->_makeAnchorHeading($2,$1)/geo;
    # '----+++++++' rule
    $text =~ s/$TWiki::regex{headerPatternDa}/$this->_makeAnchorHeading($2,(length($1)))/geo;

    # Horizontal rule
    my $hr = CGI::hr();
    $text =~ s/^---+/$hr/gm;

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $isList = 0;        # True when within a list
    my $insideTABLE = 0;
    my $result = '';
    my $isFirst = 1;

    foreach my $line ( split( /\r?\n/, $text )) {
        # Table: | cell | cell |
        # allow trailing white space after the last |
        if( $line =~ m/^(\s*)\|.*\|\s*$/ ) {
            $line =~ s/^(\s*)\|(.*)/$this->_emitTR($1,$2,$insideTABLE)/e;
            $insideTABLE = 1;
        } elsif( $insideTABLE ) {
            $result .= '</table>';
            $insideTABLE = 0;
        }

        # Lists and paragraphs
        if ( $line =~ m/^\s*$/ ) {
            unless( $insideTABLE || $isFirst ) {
                $line = '<p />';
            }
            $isList = 0;
        }
        elsif ( $line =~ m/^(\S+?)/ ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\t|   )+\S/ ) {
            if ( $line =~ s/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $3 <\/dt><dd> / ) {
                # Definition list
                $this->_addListItem( \$result, 'dl', 'dd', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \$result, 'dl', 'dd', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)\* /<li> /o ) {
                # Unnumbered list
                $this->_addListItem( \$result, 'ul', 'li', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {
                # Numbered list
                my $ot = $3;
                $ot =~ s/^(.).*/$1/;
                if( $ot !~ /^\d$/ ) {
                    $ot = ' type="'.$ot.'"';
                } else {
                    $ot = '';
                }
                $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
                $this->_addListItem( \$result, 'ol', 'li', $1, $ot );
                $isList = 1;
            }
            elsif( $isList && $line =~ /^(\t|   )+\s*\S/ ) {
                # indented line extending prior list item
                $result .= $line;
                next;
            }
            else {
                $isList = 0;
            }
        } elsif( $isList && $line =~ /^(\t|   )+\s*\S/ ) {
            # indented line extending prior list item; case where indent
            # starts with is at least 3 spaces or a tab, but may not be a
            # multiple of 3.
            $result .= $line;
            next;
        }

        # Finish the list
        unless( $isList ) {
            $this->_addListItem( \$result, '', '', '' );
            $isList = 0;
        }

        $result .= $line;
        $isFirst = 0;
    }

    if( $insideTABLE ) {
        $result .= '</table>';
    }
    $this->_addListItem( \$result, '', '', '' );

    $text = $result;

    # '#WikiName' anchors
    $text =~ s/^(\#)($TWiki::regex{wikiWordRegex})/CGI::a( { name=>$this->makeAnchorName( $2 )}, '')/geom;
    $text =~ s/${STARTWW}==(\S+?|\S[^\n]*?\S)==$ENDWW/_fixedFontText($1,1)/gem;
    $text =~ s/${STARTWW}__(\S+?|\S[^\n]*?\S)__$ENDWW/<strong><em>$1<\/em><\/strong>/gm;
    $text =~ s/${STARTWW}\*(\S+?|\S[^\n]*?\S)\*$ENDWW/<strong>$1<\/strong>/gm;
    $text =~ s/${STARTWW}\_(\S+?|\S[^\n]*?\S)\_$ENDWW/<em>$1<\/em>/gm;
    $text =~ s/${STARTWW}\=(\S+?|\S[^\n]*?\S)\=$ENDWW/_fixedFontText($1,0)/gem;

    # Mailto
    # Email addresses must always be 7-bit, even within I18N sites

    # Normal mailto:foo@example.com ('mailto:' part optional)
    $text =~ s/$STARTWW((mailto\:)?[a-zA-Z0-9-_.+]+@[a-zA-Z0-9-_.]+\.[a-zA-Z0-9-_]+)$ENDWW/$this->_mailLink( $1 )/gem;

    # Handle [[][] and [[]] links
    # Escape rendering: Change ' ![[...' to ' [<nop>[...', for final unrendered ' [[...' output
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;
    # Spaced-out Wiki words with alternative link text
    # i.e. [[$1][$3]]
    $text =~ s/\[\[([^\]\n]+)\](\[([^\]\n]+)\])?\]/$this->_handleSquareBracketedLink($theWeb,$theTopic,$1,$3)/ge;

    unless( TWiki::isTrue( $prefs->getPreferencesValue('NOAUTOLINK')) ) {
        # Handle WikiWords
        $text = $this->takeOutBlocks( $text, 'noautolink', $removed );
        $text =~ s/$STARTWW(?:($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex})($TWiki::regex{anchorRegex})?/$this->_handleWikiWord($theWeb,$1,$2,$3)/geom;
        $this->putBackBlocks( \$text, $removed, 'noautolink' );
    }

    $this->putBackBlocks( \$text, $removed, 'pre' );

    # DEPRECATED plugins hook after PRE re-inserted
    $plugins->endRenderingHandler( $text );

    # replace verbatim with pre in the final output
    $this->putBackBlocks( \$text, $removedVerbatim, 'verbatim', 'pre', \&verbatimCallBack );
    $this->putBackBlocks( \$text, $removedLiterals, 'literal', '');

    $text =~ s|\n?<nop>\n$||o; # clean up clutch

    # Only put script sections back if they are allowed by options
    $this->putBackProtected( \$text, $removedScript )
      if $TWiki::cfg{AllowInlineScript};

    $this->putBackProtected( \$text, $removedHead );
    $this->putBackProtected( \$text, $removedComments );
    $this->{session}->{loginManager}->endRenderingHandler( $text );

    $plugins->postRenderingHandler( $text );
    return $text;
}

=pod

---++ StaticMethod verbatimCallBack

Callback for use with putBackBlocks that replaces &lt; and >
by their HTML entities &amp;lt; and &amp;gt;

=cut

sub verbatimCallBack {
    my $val = shift;

    # SMELL: A shame to do this, but been in TWiki.org have converted
    # 3 spaces to tabs since day 1
    $val =~ s/\t/   /g;

    return TWiki::entityEncode( $val );
}


=pod

---++ ObjectMethod TML2PlainText( $text, $web, $topic, $opts ) -> $plainText

Clean up TWiki text for display as plain text without pushing it
through the full rendering pipeline. Intended for generation of
topic and change summaries. Adds nop tags to prevent TWiki 
subsequent rendering; nops get removed at the very end.

Defuses TML.

$opts:
   * showvar - shows !%VAR% names if not expanded
   * expandvar - expands !%VARS%
   * nohead - strips ---+ headings at the top of the text
   * showmeta - does not filter meta-data

=cut

sub TML2PlainText {
    my( $this, $text, $web, $topic, $opts ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    $opts ||= '';

    $text =~ s/\r//g;  # SMELL, what about OS10?

    if( $opts =~ /showmeta/ ) {
        $text =~ s/%META:/%<nop>META:/g;
    } else {
        $text =~ s/%META:[A-Z].*?}%//g;
    }

    if( $opts =~ /expandvar/ ) {
        $text =~ s/(\%)(SEARCH){/$1<nop>$2/g; # prevent recursion
        $text = $this->{session}->handleCommonTags( $text, $web, $topic );
    } else {
        $text =~ s/%WEB%/$web/g;
        $text =~ s/%TOPIC%/$topic/g;
        my $wtn = $this->{session}->{prefs}->getPreferencesValue(
            'WIKITOOLNAME' ) || '';
        $text =~ s/%WIKITOOLNAME%/$wtn/g;
        if( $opts =~ /showvar/ ) {
            $text =~ s/%(\w+({.*?}))%/$1/g; # defuse
        } else {
            $text =~ s/%$TWiki::regex{tagNameRegex}({.*?})?%//g;  # remove
        }
    }

    # Format e-mail to add spam padding (HTML tags removed later)
    $text =~ s/$STARTWW((mailto\:)?[a-zA-Z0-9-_.+]+@[a-zA-Z0-9-_.]+\.[a-zA-Z0-9-_]+)$ENDWW/$this->_mailLink( $1 )/gem;
    $text =~ s/<!--.*?-->//gs;          # remove all HTML comments
    $text =~ s/<(?!nop)[^>]*>//g;       # remove all HTML tags except <nop>
    $text =~ s/\&[a-z]+;/ /g;           # remove entities
    if( $opts =~ /nohead/ ) {
        # skip headings on top
        while( $text =~ s/^\s*\-\-\-+\+[^\n\r]*// ) {}; # remove heading
    }
    # keep only link text of [[prot://uri.tld/ link text]] or [[][]]
    $text =~ s/\[\[$TWiki::regex{linkProtocolPattern}\:([^\s<>"]+[^\s*.,!?;:)<|])\s+(.*?)\]\]/$3/g;
    $text =~ s/\[\[([^\]]*\]\[)(.*?)\]\]/$2/g;
    # remove "Web." prefix from "Web.TopicName" link
    $text =~ s/$STARTWW(($TWiki::regex{webNameRegex})\.($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}))/$3/g;
    $text =~ s/<[^>]*>//g;              # remove all HTML tags
    $text =~ s/[\[\]\*\|=_\&\<\>]/ /g;  # remove Wiki formatting chars
    $text =~ s/^\-\-\-+\+*\s*\!*/ /gm;  # remove heading formatting and hbar
    $text =~ s/[\+\-]+/ /g;             # remove special chars
    $text =~ s/^\s+//;                  # remove leading whitespace
    $text =~ s/\s+$//;                  # remove trailing whitespace
    $text =~ s/[\r\n]+/\n/s;
    $text =~ s/[ \t]+/ /s;

    return $text;
}

=pod

---++ ObjectMethod protectPlainText($text) -> $tml

Protect plain text from expansions that would normally be done
duing rendering, such as wikiwords. Topic summaries, for example,
have to be protected this way.

=cut

sub protectPlainText {
    my( $this, $text ) = @_;

    # prevent text from getting rendered in inline search and link tool
    # tip text by escaping links (external, internal, Interwiki)
#    $text =~ s/(?<=[\s\(])((($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}))/<nop>$1/g;
#    $text =~ s/(^|(<=\W))((($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}))/<nop>$1/g;
    $text =~ s/((($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}))/<nop>$1/g;

#    $text =~ s/(?<=[\s\(])($TWiki::regex{linkProtocolPattern}\:)/<nop>$1/go;
#    $text =~ s/(^|(<=\W))($TWiki::regex{linkProtocolPattern}\:)/<nop>$1/go;
    $text =~ s/($TWiki::regex{linkProtocolPattern}\:)/<nop>$1/go;
    $text =~ s/([@%])/<nop>$1<nop>/g;    # email address, variable

    # Encode special chars into XML &#nnn; entities for use in RSS feeds
    # - no encoding for HTML pages, to avoid breaking international 
    # characters. Only works for ISO-8859-1 sites, since the Unicode
    # encoding (&#nnn;) is identical for first 256 characters. 
    # I18N TODO: Convert to Unicode from any site character set.
    if( $this->{session}->inContext( 'rss' ) &&
          defined( $TWiki::cfg{Site}{CharSet} ) &&
            $TWiki::cfg{Site}{CharSet} =~ /^iso-?8859-?1$/i ) {
        $text =~ s/([\x7f-\xff])/"\&\#" . unpack( 'C', $1 ) .';'/ge;
    }

    return $text;
}

=pod

---++ ObjectMethod makeTopicSummary (  $theText, $theTopic, $theWeb, $theFlags ) -> $tml

Makes a plain text summary of the given topic by simply trimming a bit
off the top. Truncates to $TMTRUNC chars or, if a number is specified in $theFlags,
to that length.

=cut

sub makeTopicSummary {
    my( $this, $theText, $theTopic, $theWeb, $theFlags ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    $theFlags ||= '';

    my $htext = $this->TML2PlainText( $theText, $theWeb, $theTopic, $theFlags);
    $htext =~ s/\n+/ /g;

    # FIXME I18N: Avoid splitting within multi-byte characters (e.g. EUC-JP
    # encoding) by encoding bytes as Perl UTF-8 characters in Perl 5.8+. 
    # This avoids splitting within a Unicode codepoint (or a UTF-16
    # surrogate pair, which is encoded as a single Perl UTF-8 character),
    # but we ideally need to avoid splitting closely related Unicode codepoints.
    # Specifically, this means Unicode combining character sequences (e.g.
    # letters and accents) - might be better to split on word boundary if
    # possible.

    # limit to n chars
    my $nchar = $theFlags;
    unless( $nchar =~ s/^.*?([0-9]+).*$/$1/ ) {
        $nchar = $TMLTRUNC;
    }
    $nchar = $MINTRUNC if( $nchar < $MINTRUNC );
    $htext =~ s/^(.{$nchar}.*?)($TWiki::regex{mixedAlphaNumRegex}).*$/$1$2 \.\.\./s;

    # Convert standard excapes incl newline, $n and $n() to permit embedding in TWiki tables (Item2496)
    $htext = TWiki::expandStandardEscapes($htext);
    $htext =~ s/\s+/ /g;

    return $this->protectPlainText( $htext );
}

=pod

---++ ObjectMethod takeOutProtected( \$text, $re, \%map ) -> $text

   * =$text= - Text to process
   * =$re= - Regular expression that matches tag expressions to remove
   * =\%map= - Reference to a hash to contain the removed blocks

Return value: $text with blocks removed

used to extract from $text comment type tags like &lt;!DOCTYPE blah>

WARNING: if you want to take out &lt;!-- comments --> you _will_ need to re-write all the takeOuts
	to use a different placeholder

=cut

sub takeOutProtected {
	my( $this, $intext, $re, $map ) = @_;
	ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

	$intext =~ s/($re)/_replaceBlock($1, $map)/ge;

	return $intext;
}

sub _replaceBlock {
	my( $scoop, $map ) = @_;
	my $placeholder = $placeholderMarker;
    $placeholderMarker++;
	$map->{$placeholder}{text} = $scoop;

	return '<!--'.$TWiki::TranslationToken.$placeholder.
      $TWiki::TranslationToken.'-->';
}

=pod

---++ ObjectMethod putBackProtected( \$text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =\$text= - reference to text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks

Reverses the actions of takeOutProtected.

=cut

sub putBackProtected {
    my( $this, $text, $map ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    foreach my $placeholder ( keys %$map ) {
        my $val = $map->{$placeholder}{text};
        $$text =~ s/<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->/$val/;
        delete( $map->{$placeholder} );
    }
}

=pod

---++ ObjectMethod takeOutBlocks( \$text, $tag, \%map ) -> $text

   * =$text= - Text to process
   * =$tag= - XHTML-style tag.
   * =\%map= - Reference to a hash to contain the removed blocks

Return value: $text with blocks removed

Searches through $text and extracts blocks delimited by a tag, appending each
onto the end of the @buffer and replacing with a token
string which is not affected by TWiki rendering.  The text after these
substitutions is returned.

Parameters to the open tag are recorded.

This is _different_ to takeOutProtected, because it requires tags
to be on their own line. it also supports a callback for post-
processing the data before re-insertion.

=cut

sub takeOutBlocks {
    my( $this, $intext, $tag, $map ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    return $intext unless( $intext =~ m/<$tag\b/i );

    my $out = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split/(<\/?$tag[^>]*>)/i, $intext ) {
    	if ($token =~ /<$tag\b([^>]*)?>/i) {
    		$depth++;
    		if ($depth eq 1) {
    			$tagParams = $1;
    			next;
    		}
    	} elsif ($token =~ /<\/$tag>/i) {
            if ($depth > 0) {
                $depth--;
                if ($depth eq 0) {
                    my $placeholder = $tag.$placeholderMarker;
                    $placeholderMarker++;
                    $map->{$placeholder}{text} = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= '<!--'.$TWiki::TranslationToken.$placeholder.
                      $TWiki::TranslationToken.'-->';
                    $scoop = '';
                    next;
                }
            }
    	}
    	if ($depth > 0) {
    		$scoop .= $token;
    	} else {
    		$out .= $token;
    	}
    }

	# unmatched tags
	if (defined($scoop) && ($scoop ne '')) {
		my $placeholder = $tag.$placeholderMarker;
		$placeholderMarker++;
		$map->{$placeholder}{text} = $scoop;
		$map->{$placeholder}{params} = $tagParams;
		$out .= '<!--'.$TWiki::TranslationToken.$placeholder.
          $TWiki::TranslationToken.'-->';
	}


    return $out;
}

=pod

---++ ObjectMethod putBackBlocks( \$text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =\$text= - reference to text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag. If undefined, uses $tag.
   * =$callback= - Reference to function to call on each block being inserted (optional)

Reverses the actions of takeOutBlocks.

Each replaced block is processed by the callback (if there is one) before
re-insertion.

Parameters to the outermost cut block are replaced into the open tag,
even if that tag is changed. This allows things like
&lt;verbatim class=''>
to be mapped to
&lt;pre class=''>

Cool, eh what? Jolly good show.

And if you set $newtag to '', we replace the taken out block with the valuse itself
   * which i'm using to stop the rendering process, but then at the end put in the html directly
   (for <literal> tag.

=cut

sub putBackBlocks {
    my( $this, $text, $map, $tag, $newtag, $callback ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    $newtag = $tag if (!defined($newtag));

    foreach my $placeholder ( keys %$map ) {
        if( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || '';
            my $val = $map->{$placeholder}{text};
            $val = &$callback( $val ) if ( defined( $callback ));
            if ($newtag eq '') {
            	$$text =~ s(<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->)($val);
            } else {
            	$$text =~ s(<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->)
              	(<$newtag$params>$val</$newtag>);
            }
            delete( $map->{$placeholder} );
        }
    }
    
	if ($newtag eq '') {
		$$text =~ s/&#60;\/?$tag&#62;//ge;
	}
}

=pod

---++ ObjectMethod renderRevisionInfo($web, $topic, $meta, $rev, $format) -> $string

Obtain and render revision info for a topic.
   * =$web= - the web of the topic
   * =$topic= - the topic
   * =$meta= if specified, get rev info from here. If not specified, or meta contains rev info for a different version than the one requested, will reload the topic
   * =$rev= - the rev number, defaults to latest rev
   * =$format= - the render format, defaults to =$rev - $time - $wikiusername=
=$format= can contain the following keys for expansion:
   | =$web= | the web name |
   | =$topic= | the topic name |
   | =$rev= | the rev number |
   | =$comment= | the comment |
   | =$username= | the login of the saving user |
   | =$wikiname= | the wikiname of the saving user |
   | =$wikiusername= | the web.wikiname of the saving user |
   | =$date= | the date of the rev (no time) |
   | =$time= | the time of the rev |
   | =$min=, =$sec=, etc. | Same date format qualifiers as GMTIME |

=cut

sub renderRevisionInfo {
    my( $this, $web, $topic, $meta, $rrev, $format ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    my $store = $this->{session}->{store};

    if( $rrev ) {
        $rrev = $store->cleanUpRevID( $rrev );
    }

    unless( $meta ) {
        my $text;
        ( $meta, $text ) = $store->readTopic( undef, $web, $topic, $rrev );
    }
    my( $date, $user, $rev, $comment ) = $meta->getRevisionInfo( $rrev );

    my $wun = '';
    my $wn = '';
    my $un = '';
    if( $user ) {
        $wun = $user->webDotWikiName();
        $wn = $user->wikiName();
        $un = $user->login();
    }

    my $value = $format || 'r$rev - $date - $time - $wikiusername';
    $value =~ s/\$web/$web/gi;
    $value =~ s/\$topic/$topic/gi;
    $value =~ s/\$rev/$rev/gi;
    $value =~ s/\$time/TWiki::Time::formatTime($date, '$hour:$min:$sec')/gei;
    $value =~ s/\$date/TWiki::Time::formatTime($date, '$day $mon $year')/gei;
    $value =~ s/(\$(rcs|http|email|iso))/TWiki::Time::formatTime($date, $1 )/gei;
    if( $value =~ /\$(sec|min|hou|day|wday|dow|week|mo|ye|epoch|tz)/ ) {
        $value = TWiki::Time::formatTime( $date, $value );
    }
    $value =~ s/\$comment/$comment/gi;
    $value =~ s/\$username/$un/gi;
    $value =~ s/\$wikiname/$wn/gi;
    $value =~ s/\$wikiusername/$wun/gi;

    return $value;
}

=pod

---++ ObjectMethod summariseChanges($user, $web, $topic, $orev, $nrev, $tml) -> $text

   * =$user= - user (null to ignore permissions)
   * =$web= - web
   * =$topic= - topic
   * =$orev= - older rev
   * =$nrev= - later rev
   * =$tml= - if true will generate renderable TML (i.e. HTML with NOPs. if false will generate a summary suitable for use in plain text (mail, for example)
Generate a (max 3 line) summary of the differences between the revs.

If there is only one rev, a topic summary will be returned.

If =$tml= is not set, all HTML will be removed.

In non-tml, lines are truncated to 70 characters. Differences are shown using + and - to indicate added and removed text.

=cut

sub summariseChanges {
    my( $this, $user, $web, $topic, $orev, $nrev, $tml ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    #ASSERT($user->isa( 'TWiki::User')) if DEBUG;
    my $summary = '';
    my $store = $this->{session}->{store};

    $orev = $nrev - 1 unless (defined($orev) || !defined($nrev));

    my( $nmeta, $ntext ) = $store->readTopic( $user, $web, $topic, $nrev );

    if( $nrev && $nrev > 1 && $orev ne $nrev ) {
        my $metaPick = qr/^[A-Z](?!OPICINFO)/; # all except TOPICINFO
        # there was a prior version. Diff it.
        $ntext = $this->TML2PlainText(
            $ntext, $web, $topic, 'nonop' )."\n".
              $nmeta->stringify( $metaPick );

        my( $ometa, $otext ) = $store->readTopic( $user, $web, $topic, $orev );
        $otext = $this->TML2PlainText(
            $otext, $web, $topic, 'nonop' )."\n".
              $ometa->stringify( $metaPick );

        my $blocks = TWiki::Merge::simpleMerge( $otext, $ntext, qr/[\r\n]+/ );
        # sort through, keeping one line of context either side of a change
        my @revised;
        my $getnext = 0;
        my $prev = '';
        my $ellipsis = $tml ? '&hellip;' : '...';
        my $trunc = $tml ? $TMLTRUNC : $PLAINTRUNC;
        while ( scalar @$blocks && scalar( @revised ) < $SUMMARYLINES ) {
            my $block = shift( @$blocks );
            next unless $block =~ /\S/;
            my $trim = length($block) > $trunc;
            $block =~ s/^(.{$trunc}).*$/$1/ if( $trim );
            if ( $block =~ m/^[-+]/ ) {
                if( $tml ) {
                    $block =~ s/^-(.*)$/CGI::del( $1 )/se;
                    $block =~ s/^\+(.*)$/CGI::ins( $1 )/se;
                } elsif ( $this->{session}->inContext('rss')) {
                    $block =~ s/^-/REMOVED: /;
                    $block =~ s/^\+/INSERTED: /;
                }
                push( @revised, $prev ) if $prev;
                $block .= $ellipsis if $trim;
                push( @revised, $block );
                $getnext = 1;
                $prev = '';
            } else {
                if( $getnext ) {
                    $block .= $ellipsis if $trim;
                    push( @revised, $block );
                    $getnext = 0;
                    $prev = '';
                } else {
                    $prev = $block;
                }
            }
        }
        if( $tml ) {
            $summary = join(CGI::br(), @revised );
        } else {
            $summary = join("\n", @revised );
        }
    }

    unless( $summary ) {
        $summary = $this->makeTopicSummary( $ntext, $topic, $web );
    }

    if( ! $tml ) {
        $summary = $this->protectPlainText( $summary );
    }
    return $summary;
}

=pod

---++ ObjectMethod forEachLine( $text, \&fn, \%options ) -> $newText

Iterate over each line, calling =\&fn= on each.
\%options may contain:
   * =pre= => true, will call fn for each line in pre blocks
   * =verbatim= => true, will call fn for each line in verbatim blocks
   * =noautolink= => true, will call fn for each line in =noautolink= blocks
The spec of \&fn is sub fn( \$line, \%options ) -> $newLine; the %options hash passed into this function is passed down to the sub, and the keys =in_pre=, =in_verbatim= and =in_noautolink= are set boolean TRUE if the line is from one (or more) of those block types.

The return result replaces $line in $newText.

=cut

sub forEachLine {
    my( $this, $text, $fn, $options ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    $options->{in_pre} = 0;
    $options->{in_pre} = 0;
    $options->{in_verbatim} = 0;
    $options->{in_literal} = 0;
    $options->{in_noautolink} = 0;
    my $newText = '';
    foreach my $line ( split( /([\r\n]+)/, $text ) ) {
        if( $line =~ /[\r\n]/ ) {
            $newText .= $line;
            next;
        }
        $options->{in_verbatim}++ if( $line =~ m|^\s*<verbatim\b[^>]*>\s*$|i );
        $options->{in_verbatim}-- if( $line =~ m|^\s*</verbatim>\s*$|i );
        $options->{in_literal}++ if( $line =~ m|^\s*<literal\b[^>]*>\s*$|i );
        $options->{in_literal}-- if( $line =~ m|^\s*</literal>\s*$|i );
        unless (( $options->{in_verbatim} > 0 ) || (( $options->{in_literal} > 0 ))){
            $options->{in_pre}++ if( $line =~ m|<pre\b|i );
            $options->{in_pre}-- if( $line =~ m|</pre>|i );
            $options->{in_noautolink}++ if( $line =~ m|^\s*<noautolink\b[^>]*>\s*$|i );
            $options->{in_noautolink}-- if( $line =~ m|^\s*</noautolink>\s*|i );
        }
        unless( $options->{in_pre} > 0 && !$options->{pre} ||
                $options->{in_verbatim} > 0 && !$options->{verbatim} ||
                $options->{in_literal} > 0 && !$options->{literal} ||
                $options->{in_noautolink} > 0 && !$options->{noautolink} ) {

            $line = &$fn( $line, $options );
        }
        $newText .= $line;
    }
    return $newText;
}

=pod

---++ StaticMethod replaceTopicReferences( $text, \%options ) -> $text

Callback designed for use with forEachLine, to replace topic references.
\%options contains:
   * =oldWeb= => Web of reference to replace
   * =oldTopic= => Topic of reference to replace
   * =spacedTopic= => RE matching spaced out oldTopic
   * =newWeb= => Web of new reference
   * =newTopic= => Topic of new reference
   * =inWeb= => the web which the text we are presently processing resides in
   * =fullPaths= => optional, if set forces all links to full web.topic form
For a usage example see TWiki::UI::Manage.pm

=cut

sub replaceTopicReferences {
    my( $text, $args ) = @_;

    ASSERT(defined $args->{oldWeb}) if DEBUG;
    ASSERT(defined $args->{oldTopic}) if DEBUG;
    ASSERT(defined $args->{spacedTopic}) if DEBUG;
    ASSERT(defined $args->{newWeb}) if DEBUG;
    ASSERT(defined $args->{newTopic}) if DEBUG;
    ASSERT(defined $args->{inWeb}) if DEBUG;

    my $repl = $args->{newTopic};

    $args->{inWeb} =~ s/\//./go;
    $args->{newWeb} =~ s/\//./go;
    $args->{oldWeb} =~ s/\//./go;
    my $oldWebRegex = $args->{oldWeb};

    $oldWebRegex =~ s#\.#[.\\/]#go;

    if( $args->{inWeb} ne $args->{newWeb} || $args->{fullPaths} ) {
        $repl = $args->{newWeb}.'.'.$repl;
    }

    $text =~ s/\b$oldWebRegex\.$args->{oldTopic}\b/$repl/g;
    $text =~ s/\[\[$oldWebRegex\.$args->{spacedTopic}(\](\[[^\]]+\])?\])/[[$repl$1/g;

    return $text unless( $args->{inWeb} eq $args->{oldWeb} );

    $text =~ s/([^\.]|^)$args->{oldTopic}\b/$1$repl/g;
    $text =~ s/\[\[($args->{spacedTopic})(\](\[[^\]]+\])?\])/[[$repl$2/g;

    return $text;
}

=pod

---++ StaticMethod replaceWebReferences( $text, \%options ) -> $text

Callback designed for use with forEachLine, to replace web references.
\%options contains:
   * =oldWeb= => Web of reference to replace
   * =newWeb= => Web of new reference
For a usage example see TWiki::UI::Manage.pm

=cut

sub replaceWebReferences {
    my( $text, $args ) = @_;

    ASSERT(defined $args->{oldWeb}) if DEBUG;
    ASSERT(defined $args->{newWeb}) if DEBUG;

    my $repl = $args->{newWeb};

    $args->{newWeb}=~s/\//./go;
    $args->{oldWeb}=~s/\//./go;
    my $oldWebRegex=$args->{oldWeb};

    $oldWebRegex=~s#\.#[.\\/]#go;

    $text =~ s/\b$oldWebRegex\b/$repl/g;

    return $text;
}

=pod

---++ ObjectMethod replaceWebInternalReferences( \$text, \%meta, $oldWeb, $oldTopic )

Change within-web wikiwords in $$text and $meta to full web.topic syntax.

\%options must include topics => list of topics that must have references
to them changed to include the web specifier.

=cut

sub replaceWebInternalReferences {
    my( $this, $text, $meta, $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    my @topics = $this->{session}->{store}->getTopicNames( $oldWeb );
    my $options =
      {
       # exclude this topic from the list
       topics => [ grep { !/^$oldTopic$/ } @topics ],
       inWeb => $oldWeb,
       inTopic => $oldTopic,
       oldWeb => $oldWeb,
       newWeb => $oldWeb,
      };

    $$text = $this->forEachLine( $$text, \&_replaceInternalRefs, $options );

    $meta->forEachSelectedValue( qw/^(FIELD|TOPICPARENT)$/, undef,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^TOPICMOVED$/, qw/^by$/,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^FILEATTACHMENT$/, qw/^user$/,
                                 \&_replaceInternalRefs, $options );

    ## Ok, let's do it again, but look for links to topics in the new web and remove their full paths
    @topics = $this->{session}->{store}->getTopicNames( $newWeb );
    $options =
      {
       # exclude this topic from the list
       topics => [ @topics ],
       fullPaths => 0,
       inWeb => $newWeb,
       inTopic => $oldTopic,
       oldWeb => $newWeb,
       newWeb => $newWeb,
      };

    $$text = $this->forEachLine( $$text, \&_replaceInternalRefs, $options );

    $meta->forEachSelectedValue( qw/^(FIELD|TOPICPARENT)$/, undef,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^TOPICMOVED$/, qw/^by$/,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^FILEATTACHMENT$/, qw/^user$/,
                                 \&_replaceInternalRefs, $options );

}

# callback used by replaceWebInternalReferences
sub _replaceInternalRefs {
    my( $text, $args ) = @_;
    foreach my $topic ( @{$args->{topics}} ) {
        $args->{fullPaths} =  ( $topic ne $args->{inTopic} ) if (!defined($args->{fullPaths}));
        $args->{oldTopic} = $topic;
        $args->{newTopic} = $topic;
        $args->{spacedTopic} = TWiki::spaceOutWikiWord( $topic );
        $args->{spacedTopic} =~ s/ / */g;
        $text = replaceTopicReferences( $text, $args );
    }
    return $text;
}

=pod

---++ StaticMethod renderFormFieldArg( $meta, $args ) -> $text

Parse the arguments to a $formfield specification and extract
the relevant formfield from the given meta data.

=cut

sub renderFormFieldArg {
    my( $meta, $args ) = @_;

    my $name = $args;
    my $breakArgs = '';
    my @params = split( /\,\s*/, $args, 2 );
    if( @params > 1 ) {
        $name = $params[0] || '';
        $breakArgs = $params[1] || 1;
    }
    my $value = '';
    my @fields = $meta->find( 'FIELD' );
    foreach my $field ( @fields ) {
        my $title = $field->{title} || $field->{name};
        if( $name =~ /^($field->{name}|$title)$/ ) {
            $value = $field->{value};
            $value = '' unless defined( $value );
	    if ( $breakArgs ) {
	      $value =~ s/^\s*(.*?)\s*$/$1/go;
	      $value = breakName( $value, $breakArgs );
	    }

            return $value;
        }
    }
    return '';
}

=pod

---++ StaticMethod breakName( $text, $args) -> $text

   * =$text= - text to "break"
   * =$args= - string of format (\d+)([,\s*]\.\.\.)?)
Hyphenates $text every $1 characters, or if $2 is "..." then shortens to
$1 characters and appends "..." (making the final string $1+3 characters
long)

_Moved from Search.pm because it was obviously unhappy there,
as it is a rendering function_

=cut

sub breakName {
    my( $text, $args ) = @_;

    my @params = split( /[\,\s]+/, $args, 2 );
    if( @params ) {
        my $len = $params[0] || 1;
        $len = 1 if( $len < 1 );
        my $sep = '- ';
        $sep = $params[1] if( @params > 1 );
        if( $sep =~ /^\.\.\./i ) {
            # make name shorter like 'ThisIsALongTop...'
            $text =~ s/(.{$len})(.+)/$1.../s;

        } else {
            # split and hyphenate the topic like 'ThisIsALo- ngTopic'
            $text =~ s/(.{$len})/$1$sep/gs;
            $text =~ s/$sep$//;
        }
    }
    return $text;
}

1;
