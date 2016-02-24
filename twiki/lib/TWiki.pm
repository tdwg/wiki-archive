# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
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

=pod

---+ package TWiki

TWiki operates by creating a singleton object (known as the Session
object) that acts as a point of reference for all the different
modules in the system. This package is the class for this singleton,
and also contains the vast bulk of the basic constants and the per-
site configuration mechanisms.

Global variables are avoided wherever possible to avoid problems
with CGI accelerators such as mod_perl.

=cut

package TWiki;

use strict;
use Assert;
use Error qw( :try );

require 5.005;       # For regex objects and internationalisation

# Site configuration constants
use vars qw( %cfg );

# Uncomment this and the __END__ to enable AutoLoader
#use AutoLoader 'AUTOLOAD';
# You then need to autosplit TWiki.pm:
# cd lib
# perl -e 'use AutoSplit; autosplit("TWiki.pm", "auto")'

# Other computed constants
use vars qw(
            $TranslationToken
            $twikiLibDir
            %regex
            %constantTags
            %functionTags
            %contextFreeSyntax
            %restDispatch
            $VERSION $RELEASE
            $TRUE
            $FALSE
            $sharedSandbox
           );

# Token character that must not occur in any normal text - converted
# to a flag character if it ever does occur (very unlikely)
# TWiki uses $TranslationToken to mark points in the text. This is
# normally \0, which is not a useful character in any 8-bit character
# set we can find, nor in UTF-8. But if you *do* encounter problems
# with it, the workaround is to change $TranslationToken to something
# longer that is unlikely to occur in your text - for example
# muRfleFli5ble8leep (do *not* use punctuation characters or whitspace
# in the string!)
# See Codev.NationalCharTokenClash for more.
$TranslationToken= "\0";

=pod

---++ StaticMethod getTWikiLibDir() -> $path

STATIC method.

Returns the full path of the directory containing TWiki.pm

=cut

sub getTWikiLibDir {
    if( $twikiLibDir ) {
        return $twikiLibDir;
    }

    # FIXME: Should just use $INC{"TWiki.pm"} to get path used to load this
    # module.
    my $dir = '';
    foreach $dir ( @INC ) {
        if( $dir && -e "$dir/TWiki.pm" ) {
            $twikiLibDir = $dir;
            last;
        }
    }

    # fix path relative to location of called script
    if( $twikiLibDir =~ /^\./ ) {
        print STDERR "WARNING: TWiki lib path $twikiLibDir is relative; you should make it absolute, otherwise some scripts may not run from the command line.";
        my $bin;
        if( $ENV{SCRIPT_FILENAME} &&
            $ENV{SCRIPT_FILENAME} =~ /^(.+)\/[^\/]+$/ ) {
            # CGI script name
            $bin = $1;
        } elsif ( $0 =~ /^(.*)\/.*?$/ ) {
            # program name
            $bin = $1;
        } else {
            # last ditch; relative to current directory.
            require Cwd;
            import Cwd qw( cwd );
            $bin = cwd();
        }
        $twikiLibDir = "$bin/$twikiLibDir/";
        # normalize "/../" and "/./"
        while ( $twikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1| ) {
        };
        $twikiLibDir =~ s|([\\/])\.[\\/]|$1|g;
    }
    $twikiLibDir =~ s|([\\/])[\\/]*|$1|g; # reduce "//" to "/"
    $twikiLibDir =~ s|[\\/]$||;           # cut trailing "/"

    return $twikiLibDir;
}

BEGIN {

    use TWiki::Sandbox;   # system command sandbox
    use TWiki::Configure::Load;    # read configuration files

    $TRUE = 1;
    $FALSE = 0;

    if( DEBUG ) {
        # If ASSERTs are on, then warnings are errors. Paranoid,
        # but the only way to be sure we eliminate them all.
        # Look out also for $cfg{WarningsAreErrors}, below, which
        # is another way to install this handler without enabling
        # ASSERTs
        # ASSERTS are turned on by defining the environment variable
        # TWIKI_ASSERTS. If ASSERTs are off, this is assumed to be a
        # production environment, and no stack traces or paths are
        # output to the browser.
        $SIG{'__WARN__'} = sub { die @_ };
        $Error::Debug = 1; # verbose stack traces, please
    } else {
        $Error::Debug = 0; # no verbose stack traces
    }

    # DO NOT CHANGE THE FORMAT OF $VERSION
    # automatically expanded on checkin of this module
    $VERSION = '$Date: 2007-01-16 05:04:44 +0100 (Tue, 16 Jan 2007) $ $Rev: 12567 $ ';
    $RELEASE = 'TWiki-4.1.0';
    $VERSION =~ s/^.*?\((.*)\).*: (\d+) .*?$/$RELEASE, $1, build $2/;

    # Default handlers for different %TAGS%
    %functionTags = (
        ALLVARIABLES      => \&_ALLVARIABLES,
        ATTACHURL         => \&_ATTACHURL,
        ATTACHURLPATH     => \&_ATTACHURLPATH,
        DATE              => \&_DATE,
        DISPLAYTIME       => \&_DISPLAYTIME,
        ENCODE            => \&_ENCODE,
        FORMFIELD         => \&_FORMFIELD,
        GMTIME            => \&_GMTIME,
        GROUPS            => \&_GROUPS,
        HTTP_HOST         => \&_HTTP_HOST,
        HTTP              => \&_HTTP,
        HTTPS             => \&_HTTPS,
        ICON              => \&_ICON,
        ICONURL           => \&_ICONURL,
        ICONURLPATH       => \&_ICONURLPATH,
        IF                => \&_IF,
        INCLUDE           => \&_INCLUDE,
        INTURLENCODE      => \&_INTURLENCODE,
        LANGUAGES         => \&_LANGUAGES,
        MAKETEXT          => \&_MAKETEXT,
        META              => \&_META,
        METASEARCH        => \&_METASEARCH,
        NOP               => \&_NOP,
        PLUGINVERSION     => \&_PLUGINVERSION,
        PUBURL            => \&_PUBURL,
        PUBURLPATH        => \&_PUBURLPATH,
        QUERYPARAMS       => \&_QUERYPARAMS,
        QUERYSTRING       => \&_QUERYSTRING,
        RELATIVETOPICPATH => \&_RELATIVETOPICPATH,
        REMOTE_ADDR       => \&_REMOTE_ADDR,
        REMOTE_PORT       => \&_REMOTE_PORT,
        REMOTE_USER       => \&_REMOTE_USER,
        REVINFO           => \&_REVINFO,
        SCRIPTNAME        => \&_SCRIPTNAME,
        SCRIPTURL         => \&_SCRIPTURL,
        SCRIPTURLPATH     => \&_SCRIPTURLPATH,
        SEARCH            => \&_SEARCH,
        SEP               => \&_SEP,
        SERVERTIME        => \&_SERVERTIME,
        SPACEDTOPIC       => \&_SPACEDTOPIC, # deprecated, use SPACEOUT
        SPACEOUT          => \&_SPACEOUT,
        'TMPL:P'          => \&_TMPLP,
        TOPICLIST         => \&_TOPICLIST,
        URLENCODE         => \&_ENCODE,
        URLPARAM          => \&_URLPARAM,
        LANGUAGE          => \&_LANGUAGE,
        USERINFO          => \&_USERINFO,
        USERNAME          => \&_USERNAME_deprecated,
        VAR               => \&_VAR,
        WEBLIST           => \&_WEBLIST,
        WIKINAME          => \&_WIKINAME_deprecated,
        WIKIUSERNAME      => \&_WIKIUSERNAME_deprecated
       );
    $contextFreeSyntax{IF} = 1;

    # Constant tag strings _not_ dependent on config
    %constantTags = (
        ENDSECTION        => '',
        WIKIVERSION       => $VERSION,
        STARTSECTION      => '',

        STARTINCLUDE      => '',
        STOPINCLUDE       => '',
       );

    unless( ( $TWiki::cfg{DetailedOS} = $^O ) ) {
        require Config;
        $TWiki::cfg{DetailedOS} = $Config::Config{'osname'};
    }
    $TWiki::cfg{OS} = 'UNIX';
    if ($TWiki::cfg{DetailedOS} =~ /darwin/i) { # MacOS X
        $TWiki::cfg{OS} = 'UNIX';
    } elsif ($TWiki::cfg{DetailedOS} =~ /Win/i) {
        $TWiki::cfg{OS} = 'WINDOWS';
    } elsif ($TWiki::cfg{DetailedOS} =~ /vms/i) {
        $TWiki::cfg{OS} = 'VMS';
    } elsif ($TWiki::cfg{DetailedOS} =~ /bsdos/i) {
        $TWiki::cfg{OS} = 'UNIX';
    } elsif ($TWiki::cfg{DetailedOS} =~ /dos/i) {
        $TWiki::cfg{OS} = 'DOS';
    } elsif ($TWiki::cfg{DetailedOS} =~ /^MacOS$/i) { # MacOS 9 or earlier
        $TWiki::cfg{OS} = 'MACINTOSH';
    } elsif ($TWiki::cfg{DetailedOS} =~ /os2/i) {
        $TWiki::cfg{OS} = 'OS2';
    }

    # Validate and untaint Apache's SERVER_NAME Environment variable
    # for use in referencing virtualhost-based paths for separate data/ and templates/ instances, etc
    if ( $ENV{SERVER_NAME} &&
         $ENV{SERVER_NAME} =~ /^(([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6})$/ ) {
        $ENV{SERVER_NAME} =
          TWiki::Sandbox::untaintUnchecked( $ENV{SERVER_NAME} );
    }

    # readConfig is defined in TWiki::Configure::Load to allow overriding it
    TWiki::Configure::Load::readConfig();

    if( $TWiki::cfg{WarningsAreErrors} ) {
        # Note: Warnings are always errors if ASSERTs are enabled
        $SIG{'__WARN__'} = sub { die @_ };
    }

    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    # Constant tags dependent on the config
    $constantTags{AUTHREALM}       = $TWiki::cfg{AuthRealm};
    $constantTags{HOMETOPIC}       = $TWiki::cfg{HomeTopicName};
    $constantTags{MAINWEB}         = $TWiki::cfg{UsersWebName};
    $constantTags{TRASHWEB}        = $TWiki::cfg{TrashWebName};
    $constantTags{NOTIFYTOPIC}     = $TWiki::cfg{NotifyTopicName};
    $constantTags{SCRIPTSUFFIX}    = $TWiki::cfg{ScriptSuffix};
    $constantTags{LOCALSITEPREFS}  = $TWiki::cfg{LocalSitePreferences};
    $constantTags{STATISTICSTOPIC} = $TWiki::cfg{Stats}{TopicName};
    $constantTags{TWIKIWEB}        = $TWiki::cfg{SystemWebName};
    $constantTags{WEBPREFSTOPIC}   = $TWiki::cfg{WebPrefsTopicName};
    $constantTags{DEFAULTURLHOST}  = $TWiki::cfg{DefaultUrlHost};
    $constantTags{WIKIPREFSTOPIC}  = $TWiki::cfg{SitePrefsTopicName};
    $constantTags{WIKIUSERSTOPIC}  = $TWiki::cfg{UsersTopicName};
    $constantTags{WIKIWEBMASTER}   = $TWiki::cfg{WebMasterEmail};
    $constantTags{WIKIWEBMASTERNAME} = $TWiki::cfg{WebMasterName};
    if( $TWiki::cfg{NoFollow} ) {
        $constantTags{NOFOLLOW} = 'rel='.$TWiki::cfg{NoFollow};
    }
    $constantTags{ALLOWLOGINNAME} = $TWiki::cfg{Register}{AllowLoginName} || 0;

    # locale setup
    #
    #
    # Note that 'use locale' must be done in BEGIN block for regexes and
    # sorting to
    # work properly, although regexes can still work without this in
    # 'non-locale regexes' mode.

    if ( $TWiki::cfg{UseLocale} ) {
        # Set environment variables for grep 
        $ENV{LC_CTYPE} = $TWiki::cfg{Site}{Locale};

        # Load POSIX for I18N support.
        require POSIX;
        import POSIX qw( locale_h LC_CTYPE );

        # SMELL: mod_perl compatibility note: If TWiki is running under Apache,
        # won't this play with the Apache process's locale settings too?
        # What effects would this have?
        setlocale(&LC_CTYPE, $TWiki::cfg{Site}{Locale});
    }

    $constantTags{CHARSET} = $TWiki::cfg{Site}{CharSet};
    $constantTags{SHORTLANG} = $TWiki::cfg{Site}{Lang};
    $constantTags{LANG} = $TWiki::cfg{Site}{FullLang};

    # Set up pre-compiled regexes for use in rendering.  All regexes with
    # unchanging variables in match should use the '/o' option.
    # In the regex hash, all precompiled REs have "Regex" at the
    # end of the name. Anything else is a string, either intended
    # for use as a character class, or as a sub-expression in
    # another compiled RE.

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    if ( not $TWiki::cfg{UseLocale} or $] < 5.006
         or not $TWiki::cfg{Site}{LocaleRegexes} ) {

        # No locales needed/working, or Perl 5.005, so just use
        # any additional national characters defined in TWiki.cfg
        $regex{upperAlpha} = 'A-Z'.$TWiki::cfg{UpperNational};
        $regex{lowerAlpha} = 'a-z'.$TWiki::cfg{LowerNational};
        $regex{numeric}    = '\d';
        $regex{mixedAlpha} = $regex{upperAlpha}.$regex{lowerAlpha};
    } else {
        # Perl 5.006 or higher with working locales
        $regex{upperAlpha} = '[:upper:]';
        $regex{lowerAlpha} = '[:lower:]';
        $regex{numeric}    = '[:digit:]';
        $regex{mixedAlpha} = '[:alpha:]';
    }
    $regex{mixedAlphaNum} = $regex{mixedAlpha}.$regex{numeric};
    $regex{lowerAlphaNum} = $regex{lowerAlpha}.$regex{numeric};
    $regex{upperAlphaNum} = $regex{upperAlpha}.$regex{numeric};

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/. 

    $regex{linkProtocolPattern} =
      $TWiki::cfg{LinkProtocolPattern};

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $regex{headerPatternDa} = qr/^---+(\++|\#+)(.*)$/m;
    # '<h6>Header</h6>
    $regex{headerPatternHt} = qr/^<h([1-6])>(.+?)<\/h\1>/mi;
    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # TWiki concept regexes
    $regex{wikiWordRegex} = qr/[$regex{upperAlpha}]+[$regex{lowerAlphaNum}]+[$regex{upperAlpha}]+[$regex{mixedAlphaNum}]*/o;
    $regex{webNameBaseRegex} = qr/[$regex{upperAlpha}]+[$regex{mixedAlphaNum}_]*/o;
    $regex{webNameRegex} = qr/$regex{webNameBaseRegex}(?:(?:[\.\/]$regex{webNameBaseRegex})+)*/o;
    $regex{defaultWebNameRegex} = qr/_[$regex{mixedAlphaNum}_]+/o;
    $regex{anchorRegex} = qr/\#[$regex{mixedAlphaNum}_]+/o;
    $regex{abbrevRegex} = qr/[$regex{upperAlpha}]{3,}s?\b/o;

    # Simplistic email regex, e.g. for WebNotify processing - no i18n
    # characters allowed
    $regex{emailAddrRegex} = qr/([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/;

    # Filename regex, for attachments
    $regex{filenameRegex} = qr/[$regex{mixedAlphaNum}\.]+/o;

    # Multi-character alpha-based regexes
    $regex{mixedAlphaNumRegex} = qr/[$regex{mixedAlphaNum}]*/o;

    # %TAG% name
    $regex{tagNameRegex} = '['.$regex{mixedAlpha}.']['.$regex{mixedAlphaNum}.'_:]*';

    # Set statement in a topic
    $regex{bulletRegex} = '^(?:\t|   )+\*';
    $regex{setRegex} = $regex{bulletRegex}.'\s+(Set|Local)\s+';
    $regex{setVarRegex} = $regex{setRegex}.'('.$regex{tagNameRegex}.')\s*=\s*(.*)$';

    # Character encoding regexes

    # 7-bit ASCII only
    $regex{validAsciiStringRegex} = qr/^[\x00-\x7F]+$/o;

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $regex{validUtf8CharRegex} = qr{
                # Single byte - ASCII
                [\x00-\x7F] 
                |

                # 2 bytes
                [\xC2-\xDF][\x80-\xBF] 
                |

                # 3 bytes

                    # Avoid illegal codepoints - negative lookahead
                    (?!\xEF\xBF[\xBE\xBF])    

                    # Match valid codepoints
                    (?:
                    ([\xE0][\xA0-\xBF])|
                    ([\xE1-\xEC\xEE-\xEF][\x80-\xBF])|
                    ([\xED][\x80-\x9F])
                    )
                    [\x80-\xBF]
                |

                # 4 bytes 
                    (?:
                    ([\xF0][\x90-\xBF])|
                    ([\xF1-\xF3][\x80-\xBF])|
                    ([\xF4][\x80-\x8F])
                    )
                    [\x80-\xBF][\x80-\xBF]
                }xo;

    $regex{validUtf8StringRegex} =
      qr/^ (?: $regex{validUtf8CharRegex} )+ $/xo;

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $TWiki::cfg{ForceUnsafeRegexes} = 0 unless defined $TWiki::cfg{ForceUnsafeRegexes};

    # initialize lib directory early because of later 'cd's
    getTWikiLibDir();

    # "shared" between mod_perl instances
    $sharedSandbox = new TWiki::Sandbox(
        $TWiki::cfg{OS}, $TWiki::cfg{DetailedOS} );
};

use TWiki::Access;    # access control
use TWiki::Attach;    # file attachments
use TWiki::Attrs;     # tag attribute handling
use TWiki::Client;    # client session handling
use TWiki::Form;      # forms
use TWiki::Net;       # SMTP, get URL
use TWiki::Plugins;   # plugins handler
use TWiki::Prefs;     # preferences
use TWiki::Render;    # HTML generation
use TWiki::Search;    # search engine
use TWiki::Store;     # file I/O and rcs related functions
use TWiki::Templates; # TWiki template language
use TWiki::Time;      # date/time conversions
use TWiki::Users;     # user handler
use TWiki::I18N;      # i18n handler

=pod

---++ ObjectMethod UTF82SiteCharSet( $utf8 ) -> $ascii

Auto-detect UTF-8 vs. site charset in string, and convert UTF-8 into site
charset.

=cut

sub UTF82SiteCharSet {
    my( $this, $text ) = @_;

    # Detect character encoding of the full topic name from URL
    return undef if( $text =~ $regex{validAsciiStringRegex} );

    # If not UTF-8 - assume in site character set, no conversion required
    return undef unless( $text =~ $regex{validUtf8StringRegex} );

    # If site charset is already UTF-8, there is no need to convert anything:
    if ( $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i ) {
        # warn if using Perl older than 5.8
        if( $] <  5.008 ) {
            $this->writeWarning( 'UTF-8 not supported on Perl '.$].
                                 ' - use Perl 5.8 or higher..' );
        }

        # SMELL: is this true yet?
        $this->writeWarning( 'UTF-8 not yet supported as site charset -'.
                             'TWiki is likely to have problems' );
        return $text;
    }

    # Convert into ISO-8859-1 if it is the site charset
    if ( $TWiki::cfg{Site}{CharSet} =~ /^iso-?8859-?15?$/i ) {
        # ISO-8859-1 maps onto first 256 codepoints of Unicode
        # (conversion from 'perldoc perluniintro')
        $text =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) / 
          chr( ord($1) << 6 & 0xC0 | ord($2) & 0x3F )
            /egx;
    } else {
        # Convert from UTF-8 into some other site charset
        if( $] >= 5.008 ) {
            require Encode;
            import Encode qw(:fallbacks);
            # Map $TWiki::cfg{Site}{CharSet} into real encoding name
            my $charEncoding =
              Encode::resolve_alias( $TWiki::cfg{Site}{CharSet} );
            if( not $charEncoding ) {
                $this->writeWarning
                  ( 'Conversion to "'.$TWiki::cfg{Site}{CharSet}.
                    '" not supported, or name not recognised - check '.
                    '"perldoc Encode::Supported"' );
            } else {
                # Convert text using Encode:
                # - first, convert from UTF8 bytes into internal
                # (UTF-8) characters
                $text = Encode::decode('utf8', $text);    
                # - then convert into site charset from internal UTF-8,
                # inserting \x{NNNN} for characters that can't be converted
                $text =
                  Encode::encode( $charEncoding, $text,
                                  &FB_PERLQQ() );
            }
        } else {
            require Unicode::MapUTF8;    # Pre-5.8 Perl versions
            my $charEncoding = $TWiki::cfg{Site}{CharSet};
            if( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                $this->writeWarning
                  ( 'Conversion to "'.$TWiki::cfg{Site}{CharSet}.
                    '" not supported, or name not recognised - check '.
                    '"perldoc Unicode::MapUTF8"' );
            } else {
                # Convert text
                $text =
                  Unicode::MapUTF8::from_utf8({
                                               -string => $text,
                                               -charset => $charEncoding
                                              });
                # FIXME: Check for failed conversion?
            }
        }
    }
    return $text;
}

=pod

---++ ObjectMethod writeCompletePage( $text, $pageType, $contentType )

Write a complete HTML page with basic header to the browser.
   * =$text= is the text of the page body (&lt;html&gt; to &lt;/html&gt; if it's HTML)
   * =$pageType= - May be "edit", which will cause headers to be generated that force
     caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused
     data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html

This method removes noautolink and nop tags before outputting the page unless
$contentType is text/plain.

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;
    $contentType ||= 'text/html';

    if( $contentType ne 'text/plain' ) {
        # Remove <nop> and <noautolink> tags
        $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;
        $text .= "\n" unless $text =~ /\n$/s;

        my $htmlHeader = join(
            "\n",
            map { '<!--'.$_.'-->'.$this->{htmlHeaders}{$_} }
              keys %{$this->{htmlHeaders}} );
        $text =~ s!(</head>)!$htmlHeader$1!i if $htmlHeader;
        chomp($text);
    }

    unless( $this->inContext('command_line')) {
        # can't use simple length() in case we have UNICODE
        # see perldoc -f length
        my $len = do { use bytes; length( $text ); };
        $this->writePageHeader( undef, $pageType, $contentType, $len );
    }
    print $text;
}

=pod

---++ ObjectMethod writePageHeader( $query, $pageType, $contentType, $contentLength )

All parameters are optional.

   * =$query= CGI query object | Session CGI query (there is no good reason to set this)
   * =$pageType= - May be "edit", which will cause headers to be generated that force caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html
   * =$contentLength= - content-length | no content-length will be set if this is undefined, as required by HTTP1.1

Implements the post-Dec2001 release plugin API, which requires the
writeHeaderHandler in plugin to return a string of HTTP headers, CR/LF
delimited. Filters any illegal headers. Plugin headers will override
core settings.

=cut

sub writePageHeader {
    my( $this, $query, $pageType, $contentType, $contentLength ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    $query = $this->{cgiQuery} unless $query;

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    my( $pluginHeaders, $coreHeaders );

    my $hopts = {};

    # Add a content-length if one has been provided. HTTP1.1 says a
    # content-length should _not_ be specified unless the length is
    # known. There is a bug in Netscape such that it interprets a
    # 0 content-length as "download until disconnect" but that is
    # a bug. The correct way is to not set a content-length.
    $hopts->{'Content-Length'} = $contentLength if $contentLength;

    if ($pageType && $pageType eq 'edit') {
        # Get time now in HTTP header format
        my $lastModifiedString =
          TWiki::Time::formatTime(time, '$http', 'gmtime');

        # Expiry time is set high to avoid any data loss.  Each instance of 
        # Edit page has a unique URL with time-string suffix (fix for 
        # RefreshEditPage), so this long expiry time simply means that the 
        # browser Back button always works.  The next Edit on this page 
        # will use another URL and therefore won't use any cached 
        # version of this Edit page.
        my $expireHours = 24;
        my $expireSeconds = $expireHours * 60 * 60;

        # and cache control headers, to ensure edit page 
        # is cached until required expiry time.
        $hopts->{'last-modified'} = $lastModifiedString;
        $hopts->{expires} = "+${expireHours}h";
        $hopts->{'cache-control'} = "max-age=$expireSeconds";
    }

    # DEPRECATED plugins header handler. Plugins should use
    # modifyHeaderHandler instead.
    $pluginHeaders = $this->{plugins}->writeHeaderHandler( $query ) || '';
    if( $pluginHeaders ) {
        foreach ( split /\r\n/, $pluginHeaders ) {
            if ( m/^([\-a-z]+): (.*)$/i ) {
                $hopts->{$1} = $2;
            }
        }
    }

    $contentType = 'text/html' unless $contentType;
    if(defined($TWiki::cfg{Site}{CharSet})) {
      $contentType .= '; charset='.$TWiki::cfg{Site}{CharSet};
    }

    # use our version of the content type
    $hopts->{'Content-Type'} = $contentType;

    # New (since 1.026)
    $this->{plugins}->modifyHeaderHandler( $hopts, $this->{cgiQuery} );

    # add cookie(s)
    $this->{loginManager}->modifyHeader( $hopts );

    my $hdr = CGI::header( $hopts );

    print $hdr;
}

=pod

---++ ObjectMethod redirect( $url, $passthrough )

Redirects the request to =$url=, *unless*
   1 It is overridden by a plugin declaring a =redirectCgiQueryHandler=.
   1 =$session->{cgiQuery}= is =undef= or
   1 $query->param('noredirect') is set to a true value.
Thus a redirect is only generated when in a CGI context.

Normally this method will ignore parameters to the current query.
If $passthrough is set, then it will pass all parameters that were passed
to the current query on to the redirect target. If the request_method was
GET, then all parameters can be passed in the URL. If the
request_method was POST then it caches the form data and passes over a
cache reference in the redirect GET.

Passthrough is only meaningful if the redirect target is on the same server.

=cut

sub redirect {
    my( $this, $url, $passthru ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    my $query = $this->{cgiQuery};
    # if we got here without a query, there's not much more we can do
    return unless $query;
    # if noredirect is set, don't generate the redirect, throw an exception instead.
    # This is a HACK used to support TWikiDrawPlugin. It is deprecated and must be
    # replaced by REST handlers in the plugin.
    if( $query->param( 'noredirect' )) {
        die "ERROR: $url";
        return;
    }

    if ($passthru) {
        $url =~ s/\?(.*)$//;
        my $existing = $1;
        if ($ENV{REQUEST_METHOD} eq 'POST') {
            # Redirecting from a port to a get
            my $cache = $this->cacheQuery();
            if ($cache) {
                $url .= "?$cache";
            }
        } else {
            $url .= '?'.$query->query_string();
	    $url .= (($url =~ /\?/) ? ';' : '?').$existing if $existing;
        }
    }

    return if( $this->{plugins}->redirectCgiQueryHandler( $query, $url ) );
    return if( $this->{loginManager}->redirectCgiQuery( $query, $url ) );
    die "Login manager returned 0 from redirectCgiQuery";
}

=pod

---++ ObjectMethod cacheQuery() -> $queryString

Caches the current query in the params cache, and returns a rewritten
query string for the cache to be picked up again on the other side of a
redirect.

We can't encode post params into a redirect, because they may exceed the
size of the GET request. So we cache the params, and reload them when the
redirect target is reached.

=cut

sub cacheQuery {
    my $this = shift;
    my $query = $this->{cgiQuery};

    return '' unless (scalar($query->param()));
    # Don't double-cache
    return '' if ($query->param('twiki_redirect_cache'));

    require Digest::MD5;
    my $md5 = new Digest::MD5();
    $md5->add($$, time(), rand(time));
    my $uid = $TWiki::cfg{PassthroughDir}.'/passthru_'.$md5->hexdigest();
    open(F, ">$uid") || die "{PassthroughDir} cache not writable $!";
    $query->save(\*F);
    close(F);
    return 'twiki_redirect_cache='.$uid;
}

=pod

---++ StaticMethod isValidWikiWord( $name ) -> $boolean

Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my $name  = shift || '';
    return ( $name =~ m/^$regex{wikiWordRegex}$/o )
}

=pod

---++ StaticMethod isValidTopicName( $name ) -> $boolean

Check for a valid topic name

=cut

sub isValidTopicName {
    my( $name ) = @_;

    return isValidWikiWord( @_ ) || isValidAbbrev( @_ );
}

=pod

---++ StaticMethod isValidAbbrev( $name ) -> $boolean

Check for a valid ABBREV (acronym)

=cut

sub isValidAbbrev {
    my $name = shift || '';
    return ( $name =~ m/^$regex{abbrevRegex}$/o )
}

=pod

---++ StaticMethod isValidWebName( $name, $system ) -> $boolean

STATIC Check for a valid web name. If $system is true, then
system web names are considered valid (names starting with _)
otherwise only user web names are valid

=cut

sub isValidWebName {
    my $name = shift || '';
    my $sys = shift;
    return 1 if ( $sys && $name =~ m/^$regex{defaultWebNameRegex}$/o );
    return ( $name =~ m/^$regex{webNameRegex}$/o )
}

=pod

---++ ObjectMethod readOnlyMirrorWeb( $theWeb ) -> ( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote )

If this is a mirrored web, return information about the mirror. The info
is returned in a quadruple:

| site name | URL | link | note |

=cut

sub readOnlyMirrorWeb {
    my( $this, $theWeb ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    my @mirrorInfo = ( '', '', '', '' );
    if( $TWiki::cfg{SiteWebTopicName} ) {
        my $mirrorSiteName =
          $this->{prefs}->getWebPreferencesValue( 'MIRRORSITENAME', $theWeb );
        if( $mirrorSiteName && $mirrorSiteName ne $TWiki::cfg{SiteWebTopicName} ) {
            my $mirrorViewURL  =
              $this->{prefs}->getWebPreferencesValue( 'MIRRORVIEWURL', $theWeb );
            my $mirrorLink = $this->{templates}->readTemplate( 'mirrorlink' );
            $mirrorLink =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorLink =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorLink =~ s/\s*$//g;
            my $mirrorNote = $this->{templates}->readTemplate( 'mirrornote' );
            $mirrorNote =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorNote =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorNote = $this->{renderer}->getRenderedVersion
              ( $mirrorNote, $theWeb, $TWiki::cfg{HomeTopic} );
            $mirrorNote =~ s/\s*$//g;
            @mirrorInfo = ( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote );
        }
    }
    return @mirrorInfo;
}

=pod

---++ ObjectMethod getSkin () -> $string

Get the currently requested skin path

=cut

sub getSkin {
    my $this = shift;

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    my $skinpath = $this->{prefs}->getPreferencesValue( 'SKIN' ) || '';

    if( $this->{cgiQuery} ) {
        my $resurface = $this->{cgiQuery}->param( 'skin' );
        $skinpath = $resurface if $resurface;
    }

    my $epidermis = $this->{prefs}->getPreferencesValue( 'COVER' );
    $skinpath = $epidermis.','.$skinpath if $epidermis;

    if( $this->{cgiQuery} ) {
        $epidermis = $this->{cgiQuery}->param( 'cover' );
        $skinpath = $epidermis.','.$skinpath if $epidermis;
    }

    return $skinpath;
}

=pod

---++ ObjectMethod getScriptUrl( $absolute, $script, $web, $topic, ... ) -> $scriptURL

Returns the URL to a TWiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/twiki/bin/$script/$web/$topic".
   * =...= - an arbitrary number of name,value parameter pairs that will be url-encoded and added to the url. The special parameter name '#' is reserved for specifying an anchor. e.g. <tt>getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)</tt> will give <tt>.../view/x/y?a=1&b=2#XXX</tt>

If $absolute is set, generates an absolute URL. $absolute is advisory only;
TWiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

The default script url is taken from {ScriptUrlPath}, unless there is
an exception defined for the given script in {ScriptUrlPaths}. Both
{ScriptUrlPath} and {ScriptUrlPaths} may be absolute or relative URIs. If
they are absolute, then they will always generate absolute URLs. if they
are relative, then they will be converted to absolute when required (e.g.
when running from the command line, or when generating rss). If
$script is not given, absolute URLs will always be generated.

If either the web or the topic is defined, will generate a full url (including web and topic). Otherwise will generate only up to the script name. An undefined web will default to the main web name.

=cut

sub getScriptUrl {
    my( $this, $absolute, $script, $web, $topic, @params ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;
    $absolute ||= ($this->inContext( 'command_line' ) ||
                     $this->inContext( 'rss' ) ||
                       $this->inContext( 'absolute_urls' ));

    # SMELL: topics and webs that contain spaces?

    my $url;
    if( defined $TWiki::cfg{ScriptUrlPaths} && $script) {
        $url = $TWiki::cfg{ScriptUrlPaths}{$script};
    }
    unless( defined( $url )) {
        $url = $TWiki::cfg{ScriptUrlPath};
        if( $script ) {
            $url .= '/' unless $url =~ /\/$/;
            $url .= $script;
            $url .= $TWiki::cfg{ScriptSuffix} if $script;
        }
    }

    if( $absolute && $url !~ /^[a-z]+:/ ) {
        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". TWiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->{urlHost}.$url;
    }

    if( $web || $topic ) {
        ( $web, $topic ) =
          $this->normalizeWebTopicName( $web, $topic );

        $url .= urlEncode( '/'.$web.'/'.$topic );

	$url .= _make_params(0, @params);
    }

    return $url;
}

sub _make_params {
  my ( $notfirst, @args ) = @_;
  my $url = '';
  my $ps = '';
  my $anchor = '';
  while( my $p = shift @args ) {
    if( $p eq '#' ) {
      $anchor .= '#' . shift( @args );
    } else {
      $ps .= ';' . $p.'='.urlEncode(shift( @args )||'');
    }
  }
  if( $ps ) {
    $ps =~ s/^;/?/ unless $notfirst;
    $url .= $ps;
  }
  $url .= $anchor;
  return $url;
}

=pod

---++ ObjectMethod getPubUrl($absolute, $web, $topic, $attachment) -> $url

Composes a pub url. If $absolute is set, returns an absolute URL.
If $absolute is set, generates an absolute URL. $absolute is advisory only;
TWiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

$web, $topic and $attachment are optional. A partial URL path will be
generated if one or all is not given.

=cut

sub getPubUrl {
    my( $this, $absolute, $web, $topic, $attachment ) = @_;

    $absolute ||= ($this->inContext( 'command_line' ) ||
                     $this->inContext( 'rss' ) ||
                       $this->inContext( 'absolute_urls' ));

    my $url = '';
    $url .= $TWiki::cfg{PubUrlPath};
    if( $absolute && $url !~ /^[a-z]+:/ ) {
        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". TWiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->{urlHost}.$url;
    }
    if( $web || $topic || $attachment ) {
        ( $web, $topic ) =
          $this->normalizeWebTopicName( $web, $topic );

        my $path = '/'.$web.'/'.$topic;
        $path .= '/'.$attachment if $attachment;
        $url .= urlEncode( $path );
    }

    return $url;
}

=pod

---++ ObjectMethod getIconUrl( $absolute, $iconName ) -> $iconURL

Map an icon name to a URL path.

=cut

sub getIconUrl {
    my( $this, $absolute, $iconName ) = @_;

    my $iconTopic = $this->{prefs}->getPreferencesValue( 'ICONTOPIC' );
    my( $web, $topic) = $this->normalizeWebTopicName(
        $this->{webName}, $iconTopic );
    $iconName =~ s/^.*\.(.*?)$/$1/;
    return $this->getPubUrl( $absolute, $web, $topic, $iconName.'.gif' );
}

=pod

---++ ObjectMethod mapToIconFileName( $fileName, $default ) -> $fileName

Maps from a filename (or just the extension) to the name of the
file that contains the image for that file type.

=cut

sub mapToIconFileName {
    my( $this, $fileName, $default ) = @_;
	
    my @bits = ( split( /\./, $fileName ) );
    my $fileExt = lc $bits[$#bits];

    unless( $this->{_ICONMAP} ) {
        my $iconTopic = $this->{prefs}->getPreferencesValue( 'ICONTOPIC' );
        my( $web, $topic) = $this->normalizeWebTopicName(
            $this->{webName}, $iconTopic );
        local $/ = undef;
        try {
            my $icons = $this->{store}->getAttachmentStream(
                undef, $web, $topic, '_filetypes.txt' );
            %{$this->{_ICONMAP}} = split( /\s+/, <$icons> );
            close( $icons );
        } catch Error::Simple with {
            %{$this->{_ICONMAP}} = ();
        };
    }

    return $this->{_ICONMAP}->{$fileExt} || $default || 'else';
}

=pod

---++ ObjectMethod getOopsUrl( $template, @options ) -> $absoluteOopsURL

Composes a URL for an "oops" error page. The @options consists of a list
of key => value pairs. The following keys are used:
   * =-web= - web name
   * =-topic= - topic name
   * =-def= - optional template def within the main template file
   * =-params= - a single parameter, or a reference to an array of parameters  These are passed in the URL as '&param1=' etc.

Do _not_ include the "oops" part in front of the template name.

Alternatively you can pass a reference to an OopsException in place of the template. All other parameters will be ignored.

The returned URL ends up looking something like this:
"http://host/twiki/bin/oops/$web/$topic?template=$template&param1=$scriptParams[0]..."

Note: if {keep} is true in the params, then they will also be pushed into the
current query.

=cut

sub getOopsUrl {
    my $this = shift;
    ASSERT($this->isa( 'TWiki')) if DEBUG;
    my $template = shift;
    my $params;
    my $keep;
    my $query;

    if( $template->isa('TWiki::OopsException') ) {
        # The parameters were provided when the exception was thrown
        $params = $template;
        $template = $params->{template};
    } else {
        # The params are in the parameter array
        $params = { @_ };
    }

    if ($params->{keep}) {
        $query = $this->{cgiQuery};
        $keep = 1;
    }
    delete($params->{keep});

    my $web = $params->{web} || $this->{webName};
    my $topic = $params->{topic} || $this->{topicName};
    my $def = $params->{def};
    my $PARAMS = $params->{params};

    # Build a query string for the new URL.
    # Push all URL params into the current query as well if {keep} is
    # set, because if it is, GET params will be ignored when it is
    # restored.
    my @urlParams = ( template => 'oops'.$template );
    $query->param(-name => "template", -value => 'oops'.$template ) if $keep;

    if ($def) {
        push( @urlParams, def => $def );
        $query->param(-name => "def", -value => $def ) if $keep;
    }

    if( ref($PARAMS) eq "ARRAY" ) {
        my $n = 1;
        foreach my $p ( @$PARAMS ) {
            $p = '' unless defined $p;
            push( @urlParams, "param$n" => $p );
            $query->param(-name => "param$n", -value => $p ) if $keep;
            $n++;
        }
    } elsif( defined $PARAMS ) {
        push( @urlParams, param1 => $PARAMS );
        $query->param(-name => "param1", -value => $PARAMS ) if $keep;
    }

    $this->enterContext( 'absolute_urls' );
    my $url = $this->getScriptUrl( 0, 'oops', $web, $topic, @urlParams );
    $this->leaveContext( 'absolute_urls' );

    return $url;
}

=pod

---++ ObjectMethod normalizeWebTopicName( $theWeb, $theTopic ) -> ( $theWeb, $theTopic )

Normalize a Web<nop>.<nop>TopicName

See TWikiFuncDotPm for a full specification of the expansion (not duplicated here)

*WARNING* if there is no web specification (in the web or topic parameters) the web
defaults to $TWiki::cfg{UsersWebName}. If there is no topic specification, or the topic
is '0', the topic defaults to the web home topic name.

=cut

sub normalizeWebTopicName {
    my( $this, $web, $topic ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;
    ASSERT(defined $topic) if DEBUG;

    if( $topic =~ m|^(.*)[./](.*?)$| ) {
        $web = $1;
        $topic = $2;
    }
    $web ||= $cfg{UsersWebName};
    $topic ||= $cfg{HomeTopicName};
    $web =~ s/%((MAIN|TWIKI|USERS|SYSTEM|DOC)WEB)%/$this->_expandTagOnTopicRendering($1)||''/e;
    $web =~ s#\.#/#go;
    return( $web, $topic );
}

=pod

---++ ClassMethod new( $loginName, $query, \%initialContext )

Constructs a new TWiki object. Parameters are taken from the query object.

   * =$loginName= is the username of the user you want to be logged-in if none is
     available from a session or browser. Used mainly for side scripts and debugging.
   * =$query= the CGI query (may be undef, in which case an empty query is used)
   * =\%initialContext= - reference to a hash containing context name=value pairs
     to be pre-installed in the context hash

=cut

sub new {
    my( $class, $loginName, $query, $initialContext ) = @_;

    $query ||= new CGI( {} );
    my $this = bless( {}, $class );

    $this->{htmlHeaders} = {};
    $this->{context} = $initialContext || {};

    # create the various sub-objects
    $this->{sandbox} = $sharedSandbox;
    $this->{plugins} = new TWiki::Plugins( $this );
    $this->{net} = new TWiki::Net( $this );
    $this->{store} = new TWiki::Store( $this );
    $this->{search} = new TWiki::Search( $this );
    $this->{templates} = new TWiki::Templates( $this );
    $this->{attach} = new TWiki::Attach( $this );
    $this->{loginManager} = TWiki::Client::makeLoginManager( $this );
    # cache CGI information in the session object
    $this->{cgiQuery} = $query;

    $this->{users} = new TWiki::Users( $this );

    # Make %ENV safer, preventing hijack of the search path
    # SMELL: can this be done in a BEGIN block? Or is the environment
    # set per-query?
    if( $TWiki::cfg{SafeEnvPath} ) {
        $ENV{'PATH'} = $TWiki::cfg{SafeEnvPath};
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    $this->{security} = new TWiki::Access( $this );

    my $web = '';
    my $topic = $query->param( 'topic' );
    if( $topic ) {
        if( $topic =~ /^$regex{linkProtocolPattern}\:\/\//o &&
            $this->{cgiQuery} ) {
            # redirect to URI
            if ($TWiki::cfg{AllowRedirectUrl}) {
                print $this->redirect( $topic );
                return;
            } else {
                # for security, ignore redirect to URL
                $topic = '';
            }
        } elsif( $topic =~ /((?:.*[\.\/])+)(.*)/ ) {
            # is 'bin/script?topic=Webname.SomeTopic'
            $web   = $1;
            $topic = $2;
            $web =~ s/\./\//go;
            $web =~ s/\/$//o;
            # jump to WebHome if 'bin/script?topic=Webname.'
            $topic = $TWiki::cfg{HomeTopicName} if( $web && ! $topic );
        }
        # otherwise assume 'bin/script/Webname?topic=SomeTopic'
    } else {
        $topic = '';
    }

    # SMELL: "The Microsoft Internet Information Server is broken with
    # respect to additional path information. If you use the Perl DLL
    # library, the IIS server will attempt to execute the additional
    # path information as a Perl script. If you use the ordinary file
    # associations mapping, the path information will be present in the
    # environment, but incorrect. The best thing to do is to avoid using
    # additional path information."

    # Clean up PATH_INFO problems, e.g.  Support.CobaltRaqInstall.  A valid
    # PATH_INFO is '/Main/WebHome', i.e. the text after the script name;
    # invalid PATH_INFO is often a full path starting with '/cgi-bin/...'.
    my $pathInfo = $query->path_info();
    my $cgiScriptName = $ENV{'SCRIPT_NAME'} || '';
    $pathInfo =~ s!$cgiScriptName/!/!i;

    # Get the web and topic names from PATH_INFO
    if( $pathInfo =~ /\/((?:.*[\.\/])+)(.*)/ ) {
        # is 'bin/script/Webname/SomeTopic' or 'bin/script/Webname/'
        $web   = $1 unless $web;
        $topic = $2 unless $topic;
        $web =~ s/\./\//go;
        $web =~ s/\/$//o;
    } elsif( $pathInfo =~ /\/(.*)/ ) {
        # is 'bin/script/Webname' or 'bin/script/'
        $web = $1 unless $web;
    }

    # All roads lead to WebHome
    $topic = $TWiki::cfg{HomeTopicName} if ( $topic =~ /\.\./ );
    $topic =~ s/$TWiki::cfg{NameFilter}//go;
    $topic = $TWiki::cfg{HomeTopicName} unless $topic;
    $this->{topicName} = TWiki::Sandbox::untaintUnchecked( $topic );

    $web   =~ s/$TWiki::cfg{NameFilter}//go;
    $this->{requestedWebName} = TWiki::Sandbox::untaintUnchecked( $web ); #can be an empty string
    $web = $TWiki::cfg{UsersWebName} unless $web;
    $this->{webName} = TWiki::Sandbox::untaintUnchecked( $web );

    # Convert UTF-8 web and topic name from URL into site charset
    # if necessary - no effect if URL is not in UTF-8
    # handle topic and web names seperately; encoding is not necessarily shared
    my $webNameTemp = $this->UTF82SiteCharSet( $this->{webName} );
    if ( $webNameTemp ) {
        $this->{webName} = $webNameTemp;
    }

    my $topicNameTemp = $this->UTF82SiteCharSet( $this->{topicName} );
    if ( $topicNameTemp ) {
        $this->{topicName} = $topicNameTemp;
    }

    # Item3270 - here's the appropriate place to enforce TWiki spec:
    # All topic name sources are evaluated, site charset applied
    $this->{topicName}  =
        TWiki::Sandbox::untaintUnchecked(ucfirst $this->{topicName});

    $this->{scriptUrlPath} = $TWiki::cfg{ScriptUrlPath};

    my $url = $query->url();
    if( $url && $url =~ m!^([^:]*://[^/]*)(.*)/.*$! && $2 ) {
        $this->{urlHost} = $1;
        # If the urlHost in the url is localhost, this is a lot less
        # useful than the default url host. This is because new CGI("")
        # assigns this host by default - it's a default setting, used
        # when there is nothing better available.
        if( $this->{urlHost} eq 'http://localhost' ) {
            $this->{urlHost} = $TWiki::cfg{DefaultUrlHost};
        } elsif( $TWiki::cfg{RemovePortNumber} ) {
            $this->{urlHost} =~ s/\:[0-9]+$//;
        }
        if( $TWiki::cfg{GetScriptUrlFromCgi} ) {
            # SMELL: this is a really dangerous hack. It will fail
            # spectacularly with mod_perl.
            # SMELL: why not just use $query->script_name?
            $this->{scriptUrlPath} = $2;
        }
    } else {
        $this->{urlHost} = $TWiki::cfg{DefaultUrlHost};
    }

    # setup the cgi session, from a cookie or the url. this may return
    # the login, but even if it does, plugins will get the chance to override
    # it below.
    my $login = $this->{loginManager}->loadSession($loginName);
    my $prefs = new TWiki::Prefs( $this );
    $this->{prefs} = $prefs;

    # Push global preferences from TWiki.TWikiPreferences
    $prefs->pushGlobalPreferences();

    my $plogin = $this->{plugins}->load( $TWiki::cfg{DisableAllPlugins} );
    $login = $plogin if $plogin;
    $login ||= $TWiki::cfg{DefaultUserLogin};
    unless( $login =~ /$TWiki::cfg{LoginNameFilterIn}/) {
        die "Illegal format for login name '$login' (does not match ".$TWiki::cfg{LoginNameFilterIn}.")";
    }
    $login = TWiki::Sandbox::untaintUnchecked( $login );

    my $user = $this->{users}->findUser( $login );
    $this->{user} = $user;

    # Static session variables that can be expanded in topics when they
    # are enclosed in % signs
    # SMELL: should collapse these into one. The duplication is pretty
    # pointless. Could get rid of the SESSION_TAGS hash, might be
    # the easiest thing to do, but then that would allow other
    # upper-case named fields in the object to be accessed as well...
    $this->{SESSION_TAGS}{BASEWEB}        = $this->{webName};
    $this->{SESSION_TAGS}{BASETOPIC}      = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $this->{webName};

    # Push plugin settings
    $this->{plugins}->settings();

    # Now the rest of the preferences
    $prefs->pushGlobalPreferencesSiteSpecific();

    $prefs->pushPreferences(
        $TWiki::cfg{UsersWebName}, $user->wikiName(),
        'USER '.$user->wikiName() );

    $prefs->pushWebPreferences( $this->{webName} );

    $prefs->pushPreferences(
        $this->{webName}, $this->{topicName}, 'TOPIC' );

    $prefs->pushPreferenceValues( 'SESSION',
                                  $this->{loginManager}->getSessionValues() );

    # requires preferences (such as NEWTOPICBGCOLOR)
    $this->{renderer} = new TWiki::Render( $this );

    # Finish plugin initialization - register handlers
    $this->{plugins}->enable();

    # language information; must be loaded after
    # *all possible preferences sources* are available
    $this->{i18n} = TWiki::I18N::get( $this );

    return $this;
}

# Uncomment when enabling AutoLoader
#__END__

=pod

---++ ObjectMethod finish

Complete processing after the client's HTTP request has been responded
to. Right now this does two things:
   1 calling TWiki::Client to flushing the user's session (if any) to disk,
   2 breaking circular references to allow garbage collection in persistent
     environments

=cut

sub finish {
    my $this = shift;
    $this->{loginManager}->finish();

#    use Data::Dumper;
#    $Data::Dumper::Indent = 1;
#    warn "prepared to finish";
#    warn Dumper($this);

    $this->{prefs}->finish();
    $this->{users}->finish();
    $this->{store}->finish();

    %$this = ();
 }
=pod

---++ ObjectMethod writeLog( $action, $webTopic, $extra, $user )

   * =$action= - what happened, e.g. view, save, rename
   * =$wbTopic= - what it happened to
   * =$extra= - extra info, such as minor flag
   * =$user= - user who did the saving (user object or string user name)
Write the log for an event to the logfile

=cut

sub writeLog {
    my $this = shift;
    ASSERT($this->isa( 'TWiki')) if DEBUG;
    my $action = shift || '';
    my $webTopic = shift || '';
    my $extra = shift || '';
    my $user = shift;

    $user = $this->{user} unless $user;
    if( ref($user) && $user->isa('TWiki::User')) {
        $user = $user->wikiName();
    }
    if( $user eq $cfg{DefaultUserWikiName} ) {
       my $cgiQuery = $this->{cgiQuery};
       if( $cgiQuery ) {
           my $agent = $cgiQuery->user_agent();
           if( $agent ) {
               $agent =~ m/([\w]+)/;
               $extra .= ' '.$1;
           }
       }
    }

    my $remoteAddr = $ENV{'REMOTE_ADDR'} || '';
    my $text = "$user | $action | $webTopic | $extra | $remoteAddr |";

    $this->_writeReport( $TWiki::cfg{LogFileName}, $text );
}

=pod

---++ ObjectMethod writeWarning( $text )

Prints date, time, and contents $text to $TWiki::cfg{WarningFileName}, typically
'warnings.txt'. Use for warnings and errors that may require admin
intervention. Use this for defensive programming warnings (e.g. assertions).

=cut

sub writeWarning {
    my $this = shift;
    ASSERT($this->isa( 'TWiki')) if DEBUG;
    $this->_writeReport( $TWiki::cfg{WarningFileName}, @_ );
}

=pod

---++ ObjectMethod writeDebug( $text )

Prints date, time, and contents of $text to $TWiki::cfg{DebugFileName}, typically
'debug.txt'.  Use for debugging messages.

=cut

sub writeDebug {
    my $this = shift;
    ASSERT($this->isa( 'TWiki')) if DEBUG;
    $this->_writeReport( $TWiki::cfg{DebugFileName}, @_ );
}

# Concatenates date, time, and $text to a log file.
# The logfilename can optionally use a %DATE% variable to support
# logs that are rotated once a month.
# | =$log= | Base filename for log file |
# | =$message= | Message to print |
sub _writeReport {
    my ( $this, $log, $message ) = @_;

    if ( $log ) {
        my $time =
          TWiki::Time::formatTime( time(), '$year$mo', 'servertime');
        $log =~ s/%DATE%/$time/go;
        $time = TWiki::Time::formatTime( time(), undef, 'servertime' );

        if( open( FILE, ">>$log" ) ) {
            print FILE "| $time | $message\n";
            close( FILE );
        } else {
            print STDERR 'Could not write "'.$message.'" to '."$log: $!\n";
        }
    }
}

sub _removeNewlines {
    my( $theTag ) = @_;
    $theTag =~ s/[\r\n]+/ /gs;
    return $theTag;
}

# Convert relative URLs to absolute URIs
sub _rewriteURLInInclude {
    my( $theHost, $theAbsPath, $url ) = @_;

    # leave out an eventual final non-directory component from the absolute path
    $theAbsPath =~ s/(.*?)[^\/]*$/$1/;

    if( $url =~ /^\// ) {
        # fix absolute URL
        $url = $theHost.$url;
    } elsif( $url =~ /^\./ ) {
        # fix relative URL
        $url = $theHost.$theAbsPath.'/'.$url;
    } elsif( $url =~ /^$regex{linkProtocolPattern}\:/o ) {
        # full qualified URL, do nothing
    } elsif( $url =~ /^#/ ) {
        # anchor. This needs to be left relative to the including topic
        # so do nothing
    } elsif( $url ) {
        # FIXME: is this test enough to detect relative URLs?
        $url = $theHost.$theAbsPath.'/'.$url;
    }

    return $url;
}

sub _fixIncludeLink {
    my( $theWeb, $theLink, $theLabel ) = @_;

    # [[...][...]] link
    if( $theLink =~ /^($regex{webNameRegex}\.|$regex{defaultWebNameRegex}\.|$regex{linkProtocolPattern}\:|\/)/o ) {
        if ( $theLabel ) {
            return "[[$theLink][$theLabel]]";
        } else {
            return "[[$theLink]]";
        }
    } elsif ( $theLabel ) {
        return "[[$theWeb.$theLink][$theLabel]]";
    } else {
        return "[[$theWeb.$theLink][$theLink]]";
    }
}

# Clean-up HTML text so that it can be shown embedded in a topic
sub _cleanupIncludedHTML {
    my( $text, $host, $path, $options ) = @_;

    # FIXME: Make aware of <base> tag

    $text =~ s/^.*?<\/head>//is
      unless ( $options->{disableremoveheaders} );   # remove all HEAD
    $text =~ s/<script.*?<\/script>//gis
      unless ( $options->{disableremovescript} );    # remove all SCRIPTs
    $text =~ s/^.*?<body[^>]*>//is
      unless ( $options->{disableremovebody} );      # remove all to <BODY>
    $text =~ s/(?:\n)<\/body>.*//is
      unless ( $options->{disableremovebody} );      # remove </BODY>
    $text =~ s/(?:\n)<\/html>.*//is
      unless ( $options->{disableremoveheaders} );   # remove </HTML>
    $text =~ s/(<[^>]*>)/_removeNewlines($1)/ges
      unless ( $options->{disablecompresstags} );    # replace newlines in html tags with space
    $text =~ s/(\s(?:href|src|action)=(["']))(.*?)\2/$1._rewriteURLInInclude( $host, $path, $3 ).$2/geois
      unless ( $options->{disablerewriteurls} );

    return $text;
}

=pod

---++ StaticMethod applyPatternToIncludedText( $text, $pattern ) -> $text

Apply a pattern on included text to extract a subset

=cut

sub applyPatternToIncludedText {
    my( $theText, $thePattern ) = @_;
    $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/g;  # escape some special chars
    $thePattern = TWiki::Sandbox::untaintUnchecked( $thePattern );
    $theText = '' unless( $theText =~ s/$thePattern/$1/is );
    return $theText;
}

# Fetch content from a URL for inclusion by an INCLUDE
sub _includeUrl {
    my( $this, $url, $pattern, $web, $topic, $raw, $options, $warn ) = @_;
    my $text = '';

    # For speed, read file directly if URL matches an attachment directory
    if( $url =~ /^$this->{urlHost}$TWiki::cfg{PubUrlPath}\/([^\/\.]+)\/([^\/\.]+)\/([^\/]+)$/ ) {
        my $incWeb = $1;
        my $incTopic = $2;
        my $incAtt = $3;
        # FIXME: Check for MIME type, not file suffix
        if( $incAtt =~ m/\.(txt|html?)$/i ) {
            unless( $this->{store}->attachmentExists(
                $incWeb, $incTopic, $incAtt )) {
                return $this->_includeWarning( $warn, 'bad_attachment', $url );
            }
            if( $incWeb ne $web || $incTopic ne $topic ) {
                # CODE_SMELL: Does not account for not yet authenticated user
                unless( $this->{security}->checkAccessPermission(
                    'view', $this->{user}, undef, undef, $incTopic, $incWeb ) ) {
                    return $this->_includeWarning( $warn, 'access_denied',
                                                   "$incWeb.$incTopic" );
                }
            }
            $text = $this->{store}->readAttachment( undef, $incWeb, $incTopic,
                                                    $incAtt );
            $text = _cleanupIncludedHTML( $text, $this->{urlHost},
                                          $TWiki::cfg{PubUrlPath}, $options )
              unless $raw;
            $text = applyPatternToIncludedText( $text, $pattern )
              if( $pattern );
            $text = "<literal>\n" . $text . "\n</literal>" if ( $options->{literal} );
            return $text;
        }
        # fall through; try to include file over http based on MIME setting
    }

    return $this->_includeWarning( $warn, 'urls_not_allowed' )
      unless $TWiki::cfg{INCLUDE}{AllowURLs};

    # SMELL: should use the URI module from CPAN to parse the URL
    # SMELL: but additional CPAN adds to code bloat
    my $path = $url;
    unless ($path =~ s!^(https?)://!!) {
        $text = $this->_includeWarning( $warn, 'bad_protocol', $url );
        return $text;
    }
    my $protocol = $1;
    my ( $user, $pass );
    if ($path =~ s!([^/\@:]+)(?::([^/\@:]+))?@!!) {
        ( $user, $pass ) = ( $1, $2 );
    }
    unless ($path =~ s!([^:/]+)(?::([0-9]+))?!! ) {
        return $this->_includeWarning( $warn, 'geturl_failed', $url );
    }
    my( $host, $port ) = ( $1, $2 );

    try {
        $text = $this->{net}->getUrl( $protocol, $host, $port, $path, $user, $pass );
        $text =~ s/\r\n/\n/gs;
        $text =~ s/\r/\n/gs;
        $text =~ s/^(.*?\n)\n//s;
        my $httpHeader = $1;
        # Trap 4xx and 5xx
        die $text if ($httpHeader =~ /^HTTP\/[\d.]+\s[45]\d\d\s/s);
        my $contentType = '';
        if( $httpHeader =~ /content\-type\:\s*([^\n]*)/ois ) {
            $contentType = $1;
        }
        if( $contentType =~ /^text\/html/ ) {
            $path =~ s/[#?].*$//;
            $host = $protocol.'://'.$host;
            $host .= ":$port" if $port;
            $text = _cleanupIncludedHTML( $text, $host, $path, $options )
              unless $raw;
        } elsif( $contentType =~ /^text\/(plain|css)/ ) {
            # do nothing
        } else {
            $text = $this->_includeWarning(
                $warn, 'bad_content', $contentType );
        }
        $text = applyPatternToIncludedText( $text, $pattern ) if( $pattern );
        $text = "<literal>\n" . $text . "\n</literal>" if ( $options->{literal} );
    } catch Error::Simple with {
        my $e = shift;
        $text = $this->_includeWarning( $warn, 'geturl_failed', $url );
    };

    return $text;
}

#
# SMELL: this is _not_ a tag handler in the sense of other builtin tags,
# because it requires far more context information (the text of the topic)
# than any handler.
# SMELL: as a tag handler that also semi-renders the topic to extract the
# headings, this handler would be much better as a preRenderingHandler in
# a plugin (where head, script and verbatim sections are already protected)
#
#    * $text  : ref to the text of the current topic
#    * $topic : the topic we are in
#    * $web   : the web we are in
#    * $args  : 'Topic' [web='Web'] [depth='N']
# Return value: $tableOfContents
# Handles %<nop>TOC{...}% syntax.  Creates a table of contents
# using TWiki bulleted
# list markup, linked to the section headings of a topic. A section heading is
# entered in one of the following forms:
#    * $headingPatternSp : \t++... spaces section heading
#    * $headingPatternDa : ---++... dashes section heading
#    * $headingPatternHt : &lt;h[1-6]> HTML section heading &lt;/h[1-6]>
sub _TOC {
    my ( $this, $text, $defaultTopic, $defaultWeb, $args ) = @_;

    my $params = new TWiki::Attrs( $args );
    # get the topic name attribute
    my $topic = $params->{_DEFAULT} || $defaultTopic;

    # get the web name attribute
    $defaultWeb =~ s#/#.#g;
    my $web = $params->{web} || $defaultWeb;

    my $isSameTopic = $web eq $defaultWeb  &&  $topic eq $defaultTopic;

    $web =~ s#/#\.#g;
    my $webPath = $web;
    $webPath =~ s/\./\//g;

    # get the depth limit attribute
    my $depth = $params->{depth} || 6;

    # get the title attribute
    my $title = $params->{title} || '';
    $title = CGI::span( { class => 'twikiTocTitle' }, $title ) if( $title );

    if( $web ne $defaultWeb || $topic ne $defaultTopic ) {
        unless( $this->{security}->checkAccessPermission
                ( 'view', $this->{user}, undef, undef, $topic, $web ) ) {
            return $this->inlineAlert( 'alerts', 'access_denied',
                                       $web, $topic );
        }
        my $meta;
        ( $meta, $text ) =
          $this->{store}->readTopic( $this->{user}, $web, $topic );
    }

    my $insidePre = 0;
    my $insideVerbatim = 0;
    my $highest = 99;
    my $result  = '';
    my $verbatim = {};
    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                               $verbatim);
    $text = $this->{renderer}->takeOutBlocks( $text, 'pre',
                                               $verbatim);

    # Find URL parameters
    my $query = $this->{cgiQuery};
    my @qparams = ();
    foreach my $name ( $query->param ) {
      next if ($name eq 'keywords');
      next if ($name eq 'topic');
      push @qparams, $name => $query->param($name);
    }

    # SMELL: this handling of <pre> is archaic.
    # SMELL: use forEachLine
    foreach my $line ( split( /\r?\n/, $text ) ) {
        my $level;
        if ( $line =~ m/$regex{headerPatternDa}/o ) {
            $line = $2;
            $level = length $1;
        } elsif ( $line =~ m/$regex{headerPatternHt}/io ) {
            $line = $2;
            $level = $1;
        } else {
            next;
        }

        if( $line && $level <= $depth ) {
            # cut TOC exclude '---+ heading !! exclude this bit'
            $line =~ s/\s*$regex{headerPatternNoTOC}.+$//go;
            next unless $line;
            my $anchor = $this->{renderer}->makeAnchorName( $line );
            $highest = $level if( $level < $highest );
            my $tabs = "\t" x $level;
            # Remove *bold*, _italic_ and =fixed= formatting
            $line =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
            $line =~ s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
            $line =~ s/(^|[\s\(])=+([^\s]+?|[^\s].*?[^\s])=+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
            # Prevent WikiLinks
            $line =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;  # '[[...][...]]'
            $line =~ s/\[\[(.*?)\]\]/$1/ge;        # '[[...]]'
            $line =~ s/([\s\(])($regex{webNameRegex})\.($regex{wikiWordRegex})/$1<nop>$3/go;  # 'Web.TopicName'
            $line =~ s/([\s\(])($regex{wikiWordRegex})/$1<nop>$2/go;  # 'TopicName'
            $line =~ s/([\s\(])($regex{abbrevRegex})/$1<nop>$2/go;    # 'TLA'
            $line =~ s/([\s\-\*\(])([$regex{mixedAlphaNum}]+\:)/$1<nop>$2/go; # 'Site:page' Interwiki link
            # Prevent manual links
            $line =~ s/<[\/]?a\b[^>]*>//gi;
            # create linked bullet item, using a relative link to anchor
            my $target = $isSameTopic ?
                         _make_params(0, '#'=>$anchor,@qparams) :
                         $this->getScriptUrl(0,'view',$web,$topic,'#'=>$anchor,@qparams);
            $line = $tabs.'* ' .  CGI::a({href=>$target},$line);
            $result .= "\n".$line;
        }
    }
    if( $result ) {
        if( $highest > 1 ) {
            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }
        return CGI::div( { class=>'twikiToc' }, "$title$result\n" );
    } else {
        return '';
    }
}

=pod

---++ ObjectMethod inlineAlert($template, $def, ... ) -> $string

Format an error for inline inclusion in rendered output. The message string
is obtained from the template 'oops'.$template, and the DEF $def is
selected. The parameters (...) are used to populate %PARAM1%..%PARAMn%

=cut

sub inlineAlert {
    my $this = shift;
    my $template = shift;
    my $def = shift;

    my $text = $this->{templates}->readTemplate( 'oops'.$template,
                                                 $this->getSkin() );
    if( $text ) {
        my $blah = $this->{templates}->expandTemplate( $def );
        $text =~ s/%INSTANTIATE%/$blah/;
        # web and topic can be anything; they are not used
        $text = $this->handleCommonTags( $text, $this->{webName},
                                         $this->{topicName} );
        my $n = 1;
        while( defined( my $param = shift )) {
            $text =~ s/%PARAM$n%/$param/g;
            $n++;
        }

    } else {
        $text = CGI::h1('TWiki Installation Error')
          . 'Template "'.$template.'" not found.'.CGI::p()
            . 'Check the configuration setting for {TemplateDir}';
    }

    return $text;
}

=pod

---++ StaticMethod parseSections($text) -> ($string,$sectionlistref)

Generic parser for sections within a topic. Sections are delimited
by STARTSECTION and ENDSECTION, which may be nested, overlapped or
otherwise abused. The parser builds an array of sections, which is
ordered by the order of the STARTSECTION within the topic. It also
removes all the SECTION tags from the text, and returns the text
and the array of sections.

Each section is a =TWiki::Attrs= object, which contains the attributes
{type, name, start, end}
where start and end are character offsets in the
string *after all section tags have been removed*. All sections
are required to be uniquely named; if a section is unnamed, it
will be given a generated name. Sections may overlap or nest.

See test/unit/Fn_SECTION.pm for detailed testcases that
round out the spec.

=cut
sub parseSections {
    #my( $text _ = @_;
    my %sections;
    my @list = ();

    my $seq = 0;
    my $ntext = '';
    my $offset = 0;
    foreach my $bit (split(/(%(?:START|END)SECTION(?:{.*?})?%)/, $_[0] )) {
        if( $bit =~ /^%STARTSECTION(?:{(.*)})?%$/) {
            my $attrs = new TWiki::Attrs( $1 );
            $attrs->{type} ||= 'section';
            $attrs->{name} = $attrs->{_DEFAULT} || $attrs->{name} ||
              '_SECTION'.$seq++;
            delete $attrs->{_DEFAULT};
            my $id = $attrs->{type}.':'.$attrs->{name};
            if( $sections{$id} ) {
                # error, this named section already defined, ignore
                next;
            }
            # close open unnamed sections of the same type
            foreach my $s ( @list ) {
                if( $s->{end} < 0 && $s->{type} eq $attrs->{type} &&
                      $s->{name} =~ /^_SECTION\d+$/ ) {
                    $s->{end} = $offset;
                }
            }
            $attrs->{start} = $offset;
            $attrs->{end} = -1; # open section
            $sections{$id} = $attrs;
            push( @list, $attrs );
        } elsif( $bit =~ /^%ENDSECTION(?:{(.*)})?%$/ ) {
            my $attrs = new TWiki::Attrs( $1 );
            $attrs->{type} ||= 'section';
            $attrs->{name} = $attrs->{_DEFAULT} || $attrs->{name} || '';
            delete $attrs->{_DEFAULT};
            unless( $attrs->{name} ) {
                # find the last open unnamed section of this type
                foreach my $s ( reverse @list ) {
                    if( $s->{end} == -1 &&
                          $s->{type} eq $attrs->{type} &&
                         $s->{name} =~ /^_SECTION\d+$/ ) {
                        $attrs->{name} = $s->{name};
                        last;
                    }
                }
                # ignore it if no matching START found
                next unless $attrs->{name};
            }
            my $id = $attrs->{type}.':'.$attrs->{name};
            if( !$sections{$id} || $sections{$id}->{end} >= 0 ) {
                # error, no such open section, ignore
                next;
            }
            $sections{$id}->{end} = $offset;
        } else {
            $ntext .= $bit;
            $offset = length( $ntext );
        }
    }

    # close open sections
    foreach my $s ( @list ) {
        $s->{end} = $offset if $s->{end} < 0;
    }

    return( $ntext, \@list );
}

=pod

---++ ObjectMethod expandVariablesOnTopicCreation ( $text, $user ) -> $text

   * =$text= - text to expand
   * =$user= - reference to user object. This is the user expanded in e.g. %USERNAME. Optional, defaults to logged-in user.
Expand limited set of variables during topic creation. These are variables
expected in templates that must be statically expanded in new content.

# SMELL: no plugin handler

=cut

sub expandVariablesOnTopicCreation {
    my ( $this, $text, $user ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;
    $user ||= $this->{user};
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;

    # Chop out templateonly sections
    my( $ntext, $sections ) = parseSections( $text );

    if( scalar( @$sections )) {
        # Note that if named templateonly sections overlap, the behaviour is undefined.
        foreach my $s ( reverse @$sections ) {
            if( $s->{type} eq 'templateonly' ) {
                $ntext = substr($ntext, 0, $s->{start}).
                  substr($ntext, $s->{end}, length($ntext));
            } else {
                # put back non-templateonly sections
                my $start = $s->remove('start');
                my $end = $s->remove('end');
                $ntext = substr($ntext, 0, $start).
                  '%STARTSECTION{'.$s->stringify().'}%'.
                    substr($ntext, $start, $end - $start).
                      '%ENDSECTION{'.$s->stringify().'}%'.
                        substr($ntext, $end, length($ntext));
            }
        }
        $text = $ntext;
    }

    # Make sure func works, for registered tag handlers
    $TWiki::Plugins::SESSION = $this;

    # Note: it may look dangerous to override the user this way, but
    # it's actually quite safe, because only a subset of tags are
    # expanded during topic creation. if the set of tags expanded is
    # extended, then the impact has to be considered.
    my $safe = $this->{user};
    $this->{user} = $user;
    $text = $this->_processTags( $text, \&_expandTagOnTopicCreation, 16 );
    # kill markers used to prevent variable expansion
    $text =~ s/%NOP%//g;
    $this->{user} = $safe;
    return $text;
}

=pod

---++ StaticMethod entityEncode( $text, $extras ) -> $encodedText

Escape special characters to HTML numeric entities. This is *not* a generic
encoding, it is tuned specifically for use in TWiki.

HTML4.0 spec:
"Certain characters in HTML are reserved for use as markup and must be
escaped to appear literally. The "&lt;" character may be represented with
an <em>entity</em>, <strong class=html>&amp;lt;</strong>. Similarly, "&gt;"
is escaped as <strong class=html>&amp;gt;</strong>, and "&amp;" is escaped
as <strong class=html>&amp;amp;</strong>. If an attribute value contains a
double quotation mark and is delimited by double quotation marks, then the
quote should be escaped as <strong class=html>&amp;quot;</strong>.</p>

Other entities exist for special characters that cannot easily be entered
with some keyboards..."

This method encodes HTML special and any non-printable ascii
characters (except for \n and \r) using numeric entities.

FURTHER this method also encodes characters that are special in TWiki
meta-language.

$extras is an optional param that may be used to include *additional*
characters in the set of encoded characters. It should be a string
containing the additional chars.

=cut

sub entityEncode {
    my( $text, $extra) = @_;
    $extra ||= '';

    # encode all non-printable 7-bit chars (< \x1f),
    # except \n (\xa) and \r (\xd)
    # encode HTML special characters '>', '<', '&', ''' and '"'.
    # encode TML special characters '%', '|', '[', ']', '@', '_',
    # '*', and '='
    $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;
    return $text;
}

=pod

---++ StaticMethod entityDecode ( $encodedText ) -> $text

Decodes all numeric entities (e.g. &amp;#123;). _Does not_ decode
named entities such as &amp;amp; (use HTML::Entities for that)

=cut

sub entityDecode {
    my $text = shift;

    $text =~ s/&#(\d+);/chr($1)/ge;
    return $text;
}

=pod

---++ StaticMethod urlEncode( $string ) -> encoded string

Encode by converting characters that are illegal in URLs to
their %NN equivalents. This method is used for encoding
strings that must be embedded _verbatim_ in URLs; it cannot
be applied to URLs themselves, as it escapes reserved
characters such as = and ?.

RFC 1738, Dec. '94:
<verbatim>>
...Only alphanumerics [0-9a-zA-Z], the special
characters $-_.+!*'(), and reserved characters used for their
reserved purposes may be used unencoded within a URL.
</verbatim>
Reserved characters are $&+,/:;=?@ - these are _also_ encoded by
this method.

SMELL: For non-ISO-8859-1 $TWiki::cfg{Site}{CharSet}, need to convert to
UTF-8 before URL encoding. This encoding only supports 8-bit
character codes.

=cut

sub urlEncode {
    my $text = shift;

    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;

    return $text;
}

=pod

---++ StaticMethod urlDecode( $string ) -> decoded string

Reverses the encoding done in urlEncode.

=cut

sub urlDecode {
    my $text = shift;

    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

    return $text;
}

=pod

---++ StaticMethod isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

sub isTrue {
    my( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined( $value );

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    return ( $value ) ? 1 : 0;
}

=pod

---++ StaticMethod spaceOutWikiWord( $word, $sep ) -> $string

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter $sep any string may be used as separator between the word components; if $sep is undefined it defaults to a space.

=cut

sub spaceOutWikiWord {
    my $word = shift || '';
    my $sep = shift || ' ';
    $word =~ s/([$regex{lowerAlpha}])([$regex{upperAlpha}$regex{numeric}]+)/$1$sep$2/go;
    $word =~ s/([$regex{numeric}])([$regex{upperAlpha}])/$1$sep$2/go;
    return $word;
}

# Expands variables by replacing the variables with their
# values. Some example variables: %<nop>TOPIC%, %<nop>SCRIPTURL%,
# %<nop>WIKINAME%, etc.
# $web and $incs are passed in for recursive include expansion. They can
# safely be undef.
# The rules for tag expansion are:
#    1 Tags are expanded left to right, in the order they are encountered.
#    1 Tags are recursively expanded as soon as they are encountered - the algorithm is inherently single-pass
#    1 A tag is not "encountered" until the matching }% has been seen, by which time all tags in parameters will have been expanded
#    1 Tag expansions that create new tags recursively are limited to a set number of hierarchical levels of expansion
# 
# Formerly known as handleInternalTags, but renamed when it was rewritten
# because the old name clashes with the namespace of handlers.
sub _expandAllTags {
    my $this = shift;
    my $text = shift; # reference
    my ( $topic, $web ) = @_;
    $web =~ s#\.#/#go;

    # push current context
    my $memTopic = $this->{SESSION_TAGS}{TOPIC};
    my $memWeb   = $this->{SESSION_TAGS}{WEB};

    $this->{SESSION_TAGS}{TOPIC}   = $topic;
    $this->{SESSION_TAGS}{WEB}     = $web;

    # Escape ' !%VARIABLE%'
    $$text =~ s/(?<=\s)!%($regex{tagNameRegex})/&#37;$1/g;

    # Make sure func works, for registered tag handlers
    $TWiki::Plugins::SESSION = $this;

    # NOTE TO DEBUGGERS
    # The depth parameter in the following call controls the maximum number
    # of levels of expansion. If it is set to 1 then only tags in the
    # topic will be expanded; tags that they in turn generate will be
    # left unexpanded. If it is set to 2 then the expansion will stop after
    # the first recursive inclusion, and so on. This is incredible useful
    # when debugging. The default is set to 16
    # to match the original limit on search expansion, though this of
    # course applies to _all_ tags and not just search.
    $$text = $this->_processTags( $$text, \&_expandTagOnTopicRendering,
                                  16, @_ );

    # restore previous context
    $this->{SESSION_TAGS}{TOPIC}   = $memTopic;
    $this->{SESSION_TAGS}{WEB}     = $memWeb;
}

# Process TWiki %TAGS{}% by parsing the input tokenised into
# % separated sections. The parser is a simple stack-based parse,
# sufficient to ensure nesting of tags is correct, but no more
# than that.
# $depth limits the number of recursive expansion steps that
# can be performed on expanded tags.
sub _processTags {
    my $this = shift;
    my $text = shift;
    my $tagf = shift;

    return '' unless defined( $text );

    my $depth = shift;

    # my( $topic, $web ) = @_;

    unless ( $depth ) {
        my $mess = "Max recursive depth reached: $text";
        $this->writeWarning( $mess );
        # prevent recursive expansion that just has been detected
        # from happening in the error message
        $text =~ s/%(.*?)%/$1/go;
        return $text;
    }

    my $verbatim = {};
    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                               $verbatim);

    # See Item1442
    #my $percent = ($TranslationToken x 3).'%'.($TranslationToken x 3);

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = ''; # the top stack entry. Done this way instead of
    # referring to the top of the stack for efficiency. This var
    # should be considered to be $stack[$#stack]

    #my $tell = 1; # uncomment all tell lines set this to 1 to print debugging

    while ( scalar( @queue )) {
        my $token = shift( @queue );
        #print STDERR ' ' x $tell,"PROCESSING $token \n" if $tell;

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {
            #print STDERR ' ' x $tell,"CONSIDER $stackTop\n" if $tell;
            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stackTop =~ /}$/s ) {
                while ( scalar( @stack) &&
                        $stackTop !~ /^%($regex{tagNameRegex}){.*}$/so ) {
                    my $top = $stackTop;
                    #print STDERR ' ' x $tell,"COLLAPSE $top \n" if $tell;
                    $stackTop = pop( @stack ) . $top;
                }
            }
            # /s so you can have newlines in parameters
            if ( $stackTop =~ m/^%(($regex{tagNameRegex})(?:{(.*)})?)$/so ) {
                my( $expr, $tag, $args ) = ( $1, $2, $3 );
                #print STDERR ' ' x $tell,"POP $tag\n" if $tell;
                my $e = &$tagf( $this, $tag, $args, @_ );

                if ( defined( $e )) {
                    #print STDERR ' ' x $tell--,"EXPANDED $tag -> $e\n" if $tell;
                    $stackTop = pop( @stack );
                    # Recursively expand tags in the expansion of $tag
                    $stackTop .= $this->_processTags($e, $tagf, $depth-1, @_ );
                } else { # expansion failed
                    #print STDERR ' ' x $tell++,"EXPAND $tag FAILED\n" if $tell;
                    # To handle %NOP
                    # correctly, we have to handle the %VAR% case differently
                    # to the %VAR{}% case when a variable expansion fails.
                    # This is so that recursively define variables e.g.
                    # %A%B%D% expand correctly, but at the same time we ensure
                    # that a mismatched }% can't accidentally close a context
                    # that was left open when a tag expansion failed.
                    # However Cairo didn't do this, so for compatibility
                    # we have to accept that %NOP can never be fixed. if it
                    # could, then we could uncomment the following:

                    #if( $stackTop =~ /}$/ ) {
                    #    # %VAR{...}% case
                    #    # We need to push the unexpanded expression back
                    #    # onto the stack, but we don't want it to match the
                    #    # tag expression again. So we protect the %'s
                    #    $stackTop = $percent.$expr.$percent;
                    #} else
                    {
                        # %VAR% case.
                        # In this case we *do* want to match the tag expression
                        # again, as an embedded %VAR% may have expanded to
                        # create a valid outer expression. This is directly
                        # at odds with the %VAR{...}% case.
                        push( @stack, $stackTop );
                        $stackTop = '%'; # open new context
                    }
                }
            } else {
                push( @stack, $stackTop );
                $stackTop = '%'; # push a new context
                #$tell++ if ( $tell );
            }
        } else {
            $stackTop .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( scalar( @stack )) {
        my $expr = $stackTop;
        $stackTop = pop( @stack );
        $stackTop .= $expr;
    }

    #$stackTop =~ s/$percent/%/go;

    $this->{renderer}->putBackBlocks( \$stackTop, $verbatim, 'verbatim' );

    #print STDERR "FINAL $stackTop\n" if $tell;

    return $stackTop;
}

# Handle expansion of a tag during topic rendering
# $tag is the tag name
# $args is the bit in the {} (if there are any)
# $topic and $web should be passed for dynamic tags (not needed for
# session or constant tags
sub _expandTagOnTopicRendering {
    my $this = shift;
    my $tag = shift;
    my $args = shift;
    # my( $topic, $web ) = @_;

    my $e = $this->{prefs}->getPreferencesValue( $tag );
    unless( defined( $e )) {
        $e = $this->{SESSION_TAGS}{$tag};
        unless( defined( $e )) {
            $e = $constantTags{$tag};
        }
        if( !defined( $e ) && defined( $functionTags{$tag} )) {
            $e = &{$functionTags{$tag}}
              ( $this, new TWiki::Attrs(
                  $args, $contextFreeSyntax{$tag} ), @_ );
        }
    }
    return $e;
}

# Handle expansion of a tag during new topic creation. When creating a
# new topic from a template we only expand a subset of the available legal
# tags, and we expand %NOP% differently.
sub _expandTagOnTopicCreation {
    my $this = shift;
    # my( $tag, $args, $topic, $web ) = @_;

    # Required for Cairo compatibility. Ignore %NOP{...}%
    # %NOP% is *not* ignored until all variable expansion is complete,
    # otherwise them inside-out rule would remove it too early e.g.
    # %GM%NOP%TIME -> %GMTIME -> 12:00. So we ignore it here and scrape it
    # out later. We *have* to remove %NOP{...}% because it can foul up
    # brace-matching.
    return '' if $_[0] eq 'NOP' && defined $_[1];

    # Only expand a subset of legal tags. Warning: $this->{user} may be
    # overridden during this call, when a new user topic is being created.
    # This is what we want to make sure new user templates are populated
    # correctly, but you need to think about this if you extend the set of
    # tags expanded here.
    return undef unless $_[0] =~ /^(URLPARAM|DATE|(SERVER|GM)TIME|(USER|WIKI)NAME|WIKIUSERNAME|USERINFO)$/;

    return $this->_expandTagOnTopicRendering( @_ );
}

=pod

---++ ObjectMethod enterContext( $id, $val )

Add the context id $id into the set of active contexts. The $val
can be anything you like, but should always evaluate to boolean
TRUE.

An example of the use of contexts is in the use of tag
expansion. The commonTagsHandler in plugins is called every
time tags need to be expanded, and the context of that expansion
is signalled by the expanding module using a context id. So the
forms module adds the context id "form" before invoking common
tags expansion.

Contexts are not just useful for tag expansion; they are also
relevant when rendering.

Contexts are intended for use mainly by plugins. Core modules can
use $session->inContext( $id ) to determine if a context is active.

=cut

sub enterContext {
    my( $this, $id, $val ) = @_;
    $val ||= 1;
    $this->{context}->{$id} = $val;
}

=pod

---++ ObjectMethod leaveContext( $id )

Remove the context id $id from the set of active contexts.
(see =enterContext= for more information on contexts)

=cut

sub leaveContext {
    my( $this, $id ) = @_;
    my $res = $this->{context}->{$id};
    delete $this->{context}->{$id};
    return $res;
}

=pod

---++ ObjectMethod inContext( $id )

Return the value for the given context id
(see =enterContext= for more information on contexts)

=cut

sub inContext {
    my( $this, $id ) = @_;
    return $this->{context}->{$id};
}

=pod

---++ StaticMethod registerTagHandler( $tag, $fnref )

STATIC Add a tag handler to the function tag handlers.
   * =$tag= name of the tag e.g. MYTAG
   * =$fnref= Function to execute. Will be passed ($session, \%params, $web, $topic )

=cut

sub registerTagHandler {
    my ( $tag, $fnref, $syntax ) = @_;
    $functionTags{$tag} = \&$fnref;
    if( $syntax && $syntax eq 'context-free' ) {
        $contextFreeSyntax{$tag} = 1;
    }
}

=pod=

---++ StaticMethod registerRESTHandler( $subject, $verb, \&fn )

Adds a function to the dispatch table of the REST interface 
for a given subject. See TWikiScripts#rest for more info.

   * =$subject= - The subject under which the function will be registered.
   * =$verb= - The verb under which the function will be registered.
   * =\&fn= - Reference to the function.

The handler function must be of the form:
<verbatim>
sub handler(\%session,$subject,$verb) -> $text
</verbatim>
where:
   * =\%session= - a reference to the TWiki session object (may be ignored)
   * =$subject= - The invoked subject (may be ignored)
   * =$verb= - The invoked verb (may be ignored)

*Since:* TWiki::Plugins::VERSION 1.1

=cut=

sub registerRESTHandler {
   my ( $subject, $verb, $fnref) = @_;
   $restDispatch{$subject}{$verb} = \&$fnref;
}

=pod=

---++ StaticMethod restDispatch( $subject, $verb) => \&fn

Returns the handler  function associated to the given $subject and $werb,
or undef if none is found.

*Since:* TWiki::Plugins::VERSION 1.1

=cut=

sub restDispatch {
   my ( $subject, $verb) = @_;
   my $s=$restDispatch{$subject};
   if (defined($s)) {
       return $restDispatch{$subject}{$verb};
   } else {
       return undef;
   }
}

=pod

---++ ObjectMethod handleCommonTags( $text, $web, $topic ) -> $text

Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
'commonTagsHandler' plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

=cut

sub handleCommonTags {
    my( $this, $text, $theWeb, $theTopic ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;
    ASSERT($theWeb) if DEBUG;
    ASSERT($theTopic) if DEBUG;

    return $text unless $text;
    my $verbatim={};
    # Plugin Hook (for cache Plugins only)
    $this->{plugins}->beforeCommonTagsHandler( $text, $theTopic, $theWeb );

    #use a "global var", so included topics can extract and putback 
    #their verbatim blocks safetly.
    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                              $verbatim);

    my $memW = $this->{SESSION_TAGS}{INCLUDINGWEB};
    my $memT = $this->{SESSION_TAGS}{INCLUDINGTOPIC};
    $this->{SESSION_TAGS}{INCLUDINGWEB} = $theWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $theTopic;

    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                              $verbatim);


    # Plugin Hook
    $this->{plugins}->commonTagsHandler( $text, $theTopic, $theWeb, 0 );

    # process tags again because plugin hook may have added more in
    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    $this->{SESSION_TAGS}{INCLUDINGWEB} = $memW;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $memT;

    # 'Special plugin tag' TOC hack, must be done after all other expansions
    # are complete, and has to reprocess the entire topic.
    $text =~ s/%TOC(?:{(.*?)})?%/$this->_TOC($text, $theTopic, $theWeb, $1)/ge;

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering in order to join
    # table rows properly
    $text =~ s/^<nop>\r?\n//gm;

    $this->{renderer}->putBackBlocks( \$text, $verbatim, 'verbatim' );

    # TWiki Plugin Hook (for cache Plugins only)
    $this->{plugins}->afterCommonTagsHandler( $text, $theTopic, $theWeb );

    return $text;
}

=pod

---++ ObjectMethod addToHEAD( $id, $html )

Add =$html= to the HEAD tag of the page currently being generated.

Note that TWiki variables may be used in the HEAD. They will be expanded
according to normal variable expansion rules.

The 'id' is used to ensure that multiple adds of the same block of HTML don't
result in it being added many times.

=cut

sub addToHEAD {
	my ($this,$tag,$header) = @_;
    ASSERT($this->isa( 'TWiki')) if DEBUG;
	
	$header = $this->handleCommonTags( $header, $this->{webName},
                                       $this->{topicName} );
	
	$this->{htmlHeaders}{$tag} = $header;
}

=pod

---++ StaticMethod initialize( $pathInfo, $remoteUser, $topic, $url, $query ) -> ($topicName, $webName, $scriptUrlPath, $userName, $dataDir)

Return value: ( $topicName, $webName, $TWiki::cfg{ScriptUrlPath}, $userName, $TWiki::cfg{DataDir} )

Static method to construct a new singleton session instance.
It creates a new TWiki and sets the Plugins $SESSION variable to
point to it, so that TWiki::Func methods will work.

This method is *DEPRECATED* but is maintained for script compatibility.

Note that $theUrl, if specified, must be identical to $query->url()

=cut

sub initialize {
    my ( $pathInfo, $theRemoteUser, $topic, $theUrl, $query ) = @_;

    if( !$query ) {
        $query = new CGI( {} );
    }
    if( $query->path_info() ne $pathInfo ) {
        $query->path_info( $pathInfo );
    }
    if( $topic ) {
        $query->param( -name => 'topic', -value => '' );
    }
    # can't do much if $theUrl is specified and it is inconsistent with
    # the query. We are trying to get to all parameters passed in the
    # query.
    if( $theUrl && $theUrl ne $query->url()) {
        die 'Sorry, this version of TWiki does not support the url parameter to TWiki::initialize being different to the url in the query';
    }
    my $twiki = new TWiki( $theRemoteUser, $query );

    # Force the new session into the plugins context.
    $TWiki::Plugins::SESSION = $twiki;

    return ( $twiki->{topicName}, $twiki->{webName}, $twiki->{scriptUrlPath},
             $twiki->{userName}, $TWiki::cfg{DataDir} );
}

=pod

---++ StaticMethod readFile( $filename ) -> $text

Returns the entire contents of the given file, which can be specified in any
format acceptable to the Perl open() function. Fast, but inherently unsafe.

WARNING: Never, ever use this for accessing topics or attachments! Use the
Store API for that. This is for global control files only, and should be
used *only* if there is *absolutely no alternative*.

=cut

sub readFile {
    my $name = shift;
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <IN_FILE>;
    close( IN_FILE );
    $data = '' unless( defined( $data ));
    return $data;
}

sub _FORMFIELD {
    my ( $this, $params, $topic, $web ) = @_;	
    my $cgiQuery = $this->{cgiQuery};
    my $cgiRev = $cgiQuery->param('rev') if( $cgiQuery );
    $params->{rev} = $cgiRev;
    return $this->{renderer}->renderFORMFIELD( $params, $topic, $web );
}

sub _TMPLP {
    my( $this, $params ) = @_;
    return $this->{templates}->tmplP( $params );
}

sub _VAR {
    my( $this, $params, $topic, $inweb ) = @_;
    my $key = $params->{_DEFAULT};
    my $web = $params->{web} || $inweb;
    # handle %MAINWEB%-type cases
    ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );
    # always return a value, even when the key isn't defined
    return $this->{prefs}->getWebPreferencesValue( $key, $web ) || '';
}

sub _PLUGINVERSION {
    my( $this, $params ) = @_;
    $this->{plugins}->getPluginVersion( $params->{_DEFAULT} );
}

my $ifFactory;
sub _IF {
    my ( $this, $params ) = @_;

    unless( $ifFactory ) {
        require TWiki::If;
        $ifFactory = new TWiki::If();
    }

    my $expr = $ifFactory->parse( $params->{_DEFAULT} );
    return $this->inlineAlert(
        'alerts', 'generic', 'IF{', $params->stringify(), '}:',
        $ifFactory->{error} ) unless $expr;

    if( $expr->evaluate( $this )) {
        return $params->{then} || '';
    } else {
        return $params->{else} || '';
    }
}

# generate an include warning
# SMELL: varying number of parameters idiotic to handle for customized $warn
sub _includeWarning {
    my $this = shift;
    my $warn = shift;
    my $message = shift;

    if( $warn eq 'on' ) {
        return $this->inlineAlert( 'alerts', $message, @_ );
    } elsif( isTrue( $warn )) {
        # different inlineAlerts need different argument counts
        my $argument = '';
        if ($message  eq  'topic_not_found') {
            my ($web,$topic)  =  @_;
            $argument = "$web.$topic";
        }
        else {
            $argument = shift;
        }
        $warn =~ s/\$topic/$argument/go if $argument;
        return $warn;
    } # else fail silently
    return '';
}

# Processes a specific instance %<nop>INCLUDE{...}% syntax.
# Returns the text to be inserted in place of the INCLUDE command.
# $topic and $web should be for the immediate parent topic in the
# include hierarchy. Works for both URLs and absolute server paths.
sub _INCLUDE {
    my ( $this, $params, $includingTopic, $includingWeb ) = @_;

    # remember args for the key before mangling the params
    my $args = $params->stringify();

    # Remove params, so they don't get expanded in the included page
    my $path = $params->remove('_DEFAULT') || '';
    my $pattern = $params->remove('pattern');
    my $rev = $params->remove('rev');
    my $section = $params->remove('section');
    my $raw = $params->remove('raw') || '';
    my $warn = $params->remove('warn')
      || $this->{prefs}->getPreferencesValue( 'INCLUDEWARNING' );

    if( $path =~ /^https?\:/ ) {
        # include web page
        return $this->_includeUrl(
            $path, $pattern, $includingWeb, $includingTopic,
            $raw, $params, $warn );
    }

    $path =~ s/$TWiki::cfg{NameFilter}//go;    # zap anything suspicious
    if( $TWiki::cfg{DenyDotDotInclude} ) {
        # Filter out '..' from filename, this is to
        # prevent includes of '../../file'
        $path =~ s/\.+/\./g;
    } else {
        # danger, could include .htpasswd with relative path
        $path =~ s/passwd//gi;    # filter out passwd filename
    }

    # make sure we have something to include. If we don't do this, then
    # normalizeWebTopicName will default to WebHome. Item2209.
    unless( $path ) {
        # SMELL: could do with a different message here, but don't want to
        # add one right now because translators are already working
        return $this->_includeWarning( $warn, 'topic_not_found', '""','""' );
    }

    my $text = '';
    my $meta = '';
    my $includedWeb;
    my $includedTopic = $path;
    $includedTopic =~ s/\.txt$//; # strip optional (undocumented) .txt

    ($includedWeb, $includedTopic) =
      $this->normalizeWebTopicName($includingWeb, $includedTopic);

    # See Codev.FailedIncludeWarning for the history.
    unless( $this->{store}->topicExists($includedWeb, $includedTopic)) {
        return $this->_includeWarning( $warn, 'topic_not_found',
                                       $includedWeb, $includedTopic );
    }

    # prevent recursive includes. Note that the inclusion of a topic into
    # itself is not blocked; however subsequent attempts to include the
    # topic will fail. There is a hard block of 99 on any recursive include.
    my $key = $includingWeb.'.'.$includingTopic;
    my $count = grep( $key, keys %{$this->{includes}});
    $key .= $args;
    if( $this->{includes}->{$key} || $count > 99) {
        return $this->_includeWarning( $warn, 'already_included',
                                       "$includedWeb.$includedTopic", '' );
    }

    my %saveTags = %{$this->{SESSION_TAGS}};
    my $prefsMark = $this->{prefs}->mark();

    $this->{includes}->{$key} = 1;
    $this->{SESSION_TAGS}{INCLUDINGWEB} = $includingWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $includingTopic;

    # copy params into session tags
    foreach my $k ( keys %$params ) {
        $this->{SESSION_TAGS}{$k} = $params->{$k};
    }

    ( $meta, $text ) =
      $this->{store}->readTopic( undef, $includedWeb, $includedTopic,
                                 $rev );

    unless( $this->{security}->checkAccessPermission(
        'VIEW', $this->{user}, $text, $meta, $includedTopic, $includedWeb )) {
        if( isTrue( $warn )) {
            return $this->inlineAlert( 'alerts', 'access_denied',
                                       $includedTopic );
        } # else fail silently
        return '';
    }

    # remove everything before and after the selected include block
    if( !$section ) {
       $text =~ s/.*?%STARTINCLUDE%//s;
       $text =~ s/%STOPINCLUDE%.*//s;
    }

    # handle sections
    my( $ntext, $sections ) = parseSections( $text );

    my $interesting = ( defined $section );
    if( scalar( @$sections )) {
        # Rebuild the text from the sections
        $text = '';
        foreach my $s ( @$sections ) {
            if( $section && $s->{type} eq 'section' &&
                  $s->{name} eq $section) {
                $text .= substr( $ntext, $s->{start}, $s->{end}-$s->{start} );
                $interesting = 1;
                last;
            } elsif( $s->{type} eq 'include' && !$section ) {
                $text .= substr( $ntext, $s->{start}, $s->{end}-$s->{start} );
                $interesting = 1;
            }
        }
    }
    # If there were no interesting sections, restore the whole text
    $text = $ntext unless $interesting;

    $text = applyPatternToIncludedText( $text, $pattern ) if( $pattern );

    $this->_expandAllTags( \$text, $includedTopic, $includedWeb );

    # 4th parameter tells plugin that its called for an included file
    $this->{plugins}->commonTagsHandler( $text, $includedTopic,
                                         $includedWeb, 1 );

    # We have to expand tags again, because a plugin may have inserted additional
    # tags.
    $this->_expandAllTags( \$text, $includedTopic, $includedWeb );

    # If needed, fix all 'TopicNames' to 'Web.TopicNames' to get the
    # right context so that links continue to work properly
    if( $includedWeb ne $includingWeb ) {
	    my $removed = {};

        # Must handle explicit [[]] before noautolink
        # '[[TopicName]]' to '[[Web.TopicName][TopicName]]'
        $text =~ s/\[\[([^\]]+)\]\]/&_fixIncludeLink( $includedWeb, $1 )/geo;
        # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
        $text =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&_fixIncludeLink( $includedWeb, $1, $2 )/geo;

	    unless( TWiki::isTrue( $this->{prefs}->getPreferencesValue('NOAUTOLINK')) ) {
	        # Handle WikiWords
	        $text = $this->{renderer}->takeOutBlocks( $text, 'noautolink', $removed );
	    }

        # 'TopicName' to 'Web.TopicName'
        $text =~ s/(^|[\s(])($regex{webNameRegex}\.$regex{wikiWordRegex})/$1$TranslationToken$2/go;
        $text =~ s/(^|[\s(])($regex{wikiWordRegex})/$1$includedWeb\.$2/go;
        $text =~ s/(^|[\s(])$TranslationToken/$1/go;

        $this->{renderer}->putBackBlocks( \$text, $removed, 'noautolink' );
    }

    # handle tags again because of plugin hook
    $this->_expandAllTags( \$text, $includedTopic, $includedWeb );

    # restore the tags
    delete $this->{includes}->{$key};
    %{$this->{SESSION_TAGS}} = %saveTags;

    $this->{prefs}->restore( $prefsMark );
    $text =~ s/^[\r\n]+/\n/;
    $text =~ s/[\r\n]+$/\n/;

    return $text;
}

sub _HTTP {
    my( $this, $params ) = @_;
    my $res;
    if( $params->{_DEFAULT} ) {
        $res = $this->{cgiQuery}->http( $params->{_DEFAULT} );
    }
    $res = '' unless defined( $res );
    return $res;
}

sub _HTTPS {
    my( $this, $params ) = @_;
    my $res;
    if( $params->{_DEFAULT} ) {
        $res = $this->{cgiQuery}->https( $params->{_DEFAULT} );
    }
    $res = '' unless defined( $res );
    return $res;
}

sub _HTTP_HOST {
    return $ENV{HTTP_HOST} || '';
}

sub _REMOTE_ADDR {
    return $ENV{REMOTE_ADDR} || '';
}

sub _REMOTE_PORT {
    return $ENV{REMOTE_PORT} || '';
}

sub _REMOTE_USER {
    return $ENV{REMOTE_USER} || '';
}

# Only does simple search for topicmoved at present, can be expanded when required
# SMELL: this violates encapsulation of Store and Meta, by exporting
# the assumption that meta-data is stored embedded inside topic
# text.
sub _METASEARCH {
    my( $this, $params ) = @_;

    return $this->{store}->searchMetaData( $params );
}

sub _DATE {
    my $this = shift;
    return TWiki::Time::formatTime(time(), '$day $mon $year', 'gmtime');
}

sub _GMTIME {
    my( $this, $params ) = @_;
    return TWiki::Time::formatTime( time(), $params->{_DEFAULT} || '', 'gmtime' );
}

sub _SERVERTIME {
    my( $this, $params ) = @_;
    return TWiki::Time::formatTime( time(), $params->{_DEFAULT} || '', 'servertime' );
}

sub _DISPLAYTIME {
    my( $this, $params ) = @_;
    return TWiki::Time::formatTime( time(), $params->{_DEFAULT} || '', $TWiki::cfg{DisplayTimeValues} );
}

#| $web | web and  |
#| $topic | topic to display the name for |
#| $formatString | twiki format string (like in search) |
sub _REVINFO {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $format = $params->{_DEFAULT} || $params->{format};
    my $web    = $params->{web} || $theWeb;
    my $topic  = $params->{topic} || $theTopic;
    my $cgiQuery = $this->{cgiQuery};
    my $cgiRev = '';
    $cgiRev = $cgiQuery->param('rev') if( $cgiQuery );
    my $rev = $cgiRev || $params->{rev} || '';

    return $this->{renderer}->renderRevisionInfo( $web, $topic, undef,
                                                  $rev, $format );
}

sub _ENCODE {
    my( $this, $params ) = @_;
    my $type = $params->{type} || '';
    my $text = $params->{_DEFAULT} || '';
    if ( $type =~ /^entit(y|ies)$/i ) {
        return entityEncode( $text );
    } elsif ( $type =~ /^html$/i ) {
        return entityEncode( $text, "\n\r" );
    } elsif ( $type =~ /^quotes?$/i ) {
        $text =~ s/\"/\\"/go;    # escape quotes with backslash (Bugs:Item3383 fix)
        return $text;
    } else {
        $text =~ s/\r*\n\r*/<br \/>/; # Legacy.
        return urlEncode( $text );
    }
}

sub _SEARCH {
    my ( $this, $params, $topic, $web ) = @_;
    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{inline} = 1;
    $params->{baseweb} = $web;
    $params->{basetopic} = $topic;
    $params->{search} = $params->{_DEFAULT} if( $params->{_DEFAULT} );
    $params->{type} = $this->{prefs}->getPreferencesValue( 'SEARCHVARDEFAULTTYPE' ) unless( $params->{type} );

    my $s = $this->{search}->searchWeb( %$params );
    return $s;
}

sub _WEBLIST {
    my( $this, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$name';
    $format ||= '$name';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $web = $params->{web} || '';
    my $webs = $params->{webs} || 'public';
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';
    $web =~ s#\.#/#go;

    my @list = ();
    my @webslist = split( /,\s*/, $webs );
    foreach my $aweb ( @webslist ) {
        if( $aweb eq 'public' ) {
            push( @list, $this->{store}->getListOfWebs( 'user,public,allowed' ) );
        } elsif( $aweb eq 'webtemplate' ) {
            push( @list, $this->{store}->getListOfWebs( 'template,allowed' ));
        } else{
            push( @list, $aweb ) if( $this->{store}->webExists( $aweb ) );
        }
    }

    my @items;
    my $indent = CGI::span({class=>'twikiWebIndent'},'');
    foreach my $item ( @list ) {
        my $line = $format;
        $line =~ s/\$web\b/$web/g;
        $line =~ s/\$name\b/$item/g;
        $line =~ s/\$qname/"$item"/g;
        my $indenteditem = $item;
        $indenteditem =~ s#/$##g;
        $indenteditem =~ s#\w+/#$indent#g;
        $line =~ s/\$indentedname/$indenteditem/g;
        my $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        push(@items, $line);
    }
    return join( $separator, @items);
}

sub _TOPICLIST {
    my( $this, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{'format'} || '$name';
    $format ||= '$name';
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\$n/\n/;
    my $web = $params->{web} || $this->{webName};
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';
    $web =~ s#\.#/#go;

    return '' if
      $web ne $this->{webName} &&
      $this->{prefs}->getWebPreferencesValue( 'NOSEARCHALL', $web );

    my @items;
    foreach my $item ( $this->{store}->getTopicNames( $web ) ) {
        my $line = $format;
        $line =~ s/\$web\b/$web/g;
        $line =~ s/\$name\b/$item/g;
        $line =~ s/\$qname/"$item"/g;
        my $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/g;
        push( @items, $line );
    }
    return join( $separator, @items );
}

sub _QUERYSTRING {
    my $this = shift;
    return $this->{cgiQuery}->query_string();
}

sub _QUERYPARAMS {
    my ( $this, $params ) = @_;
    return '' unless $this->{cgiQuery};
    my $format = defined $params->{format} ? $params->{format} : '$name=$value';
    my $separator = defined $params->{separator} ? $params->{separator} : "\n";

    my @list;
    foreach my $name ( $this->{cgiQuery}->param() ) {
        # Issues multi-valued parameters as separate hiddens
        my $value = $this->{cgiQuery}->param( $name );
        my $entry = $format;
        $entry =~ s/\$name/$name/g;
        $entry =~ s/\$value/$value/;
        push(@list, $entry);
    }
    return expandStandardEscapes(join($separator, @list));
}

=pod

---++ StaticMethod expandStandardEscapes($str) -> $unescapedStr

Expands standard escapes used in parameter values to block evaluation. The following escapes
are handled:

| *Escape:* | *Expands To:* |
| =$n= or =$n()= | New line. Use =$n()= if followed by alphanumeric character, e.g. write =Foo$n()Bar= instead of =Foo$nBar= |
| =$nop= or =$nop()= | Is a "no operation". |
| =$quot= | Double quote (="=) |
| =$percnt= | Percent sign (=%=) |
| =$dollar= | Dollar sign (=$=) |

=cut

sub expandStandardEscapes {
    my $text = shift;
    $text =~ s/\$n\(\)/\n/gos;         # expand '$n()' to new line
    $text =~ s/\$n([^$regex{mixedAlpha}]|$)/\n$1/gos; # expand '$n' to new line
    $text =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
    $text =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $text =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $text =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
    return $text;
}

sub _URLPARAM {
    my( $this, $params ) = @_;
    my $param     = $params->{_DEFAULT} || '';
    my $newLine   = $params->{newline} || '';
    my $encode    = $params->{encode};
    my $multiple  = $params->{multiple};
    my $separator = $params->{separator} || "\n";

    my $value = '';
    if( $this->{cgiQuery} ) {
        if( TWiki::isTrue( $multiple )) {
            my @valueArray = $this->{cgiQuery}->param( $param );
            if( @valueArray ) {
                # join multiple values properly
                unless( $multiple =~ m/^on$/i ) {
                    my $item = '';
                    @valueArray = map {
                        $item = $_;
                        $_ = $multiple;
                        $_ .= $item unless( s/\$item/$item/go );
                        $_
                    } @valueArray;
                }
                $value = join ( $separator, @valueArray );
            }
        } else {
            $value = $this->{cgiQuery}->param( $param );
            $value = '' unless( defined $value );
        }
    }
    $value =~ s/\r?\n/$newLine/go if( $newLine );
    if ( $encode ) {
        if ( $encode =~ /^entit(y|ies)$/i ) {
            $value = entityEncode( $value );
        } elsif ( $encode =~ /^quotes?$/i ) {
            $value =~ s/\"/\\"/go;    # escape quotes with backslash (Bugs:Item3383 fix)
        } else {
            $value =~ s/\r*\n\r*/<br \/>/; # Legacy
            $value = urlEncode( $value );
        }
    }
    unless( $value ) {
        $value = $params->{default} || '';
    }
    return $value;
}

# This routine was introduced to URL encode Mozilla UTF-8 POST URLs in the
# TWiki Feb2003 release - encoding is no longer needed since UTF-URLs are now
# directly supported, but it is provided for backward compatibility with
# skins that may still be using the deprecated %INTURLENCODE%.
sub _INTURLENCODE {
    my( $this, $params ) = @_;
    # Just strip double quotes, no URL encoding - Mozilla UTF-8 URLs
    # directly supported now
    return $params->{_DEFAULT} || '';
}

# This routine is deprecated as of DakarRelease,
# and is maintained only for backward compatibility.
# Spacing of WikiWords is now done with %SPACEOUT%
# (and the private routine _SPACEOUT).
sub _SPACEDTOPIC {
    my ( $this, $params, $theTopic ) = @_;
    my $topic = spaceOutWikiWord( $theTopic );
    $topic =~ s/ / */g;
    return urlEncode( $topic );
}

sub _SPACEOUT {
    my ( $this, $params ) = @_;
    my $spaceOutTopic = $params->{_DEFAULT};
    my $sep = $params->{'separator'};
    $spaceOutTopic = spaceOutWikiWord( $spaceOutTopic, $sep );
    return $spaceOutTopic;
}

sub _ICON {
    my( $this, $params ) = @_;
    my $file = $params->{_DEFAULT} || '';
    # Try to map the file name to see if there is a matching filetype image
    # If no mapping could be found, use the file name that was passed
    my $iconFileName = $this->mapToIconFileName( $file, $file );
    return CGI::img( { src => $this->getIconUrl( 0, $iconFileName ),
                       width => 16, height=>16,
                       align => 'top', alt => $iconFileName, border => 0 });
}

sub _ICONURL {
    my( $this, $params ) = @_;
    my $file = ( $params->{_DEFAULT} || '' );

    return $this->getIconUrl( 1, $file );
}

sub _ICONURLPATH {
    my( $this, $params ) = @_;
    my $file = ( $params->{_DEFAULT} || '' );

    return $this->getIconUrl( 0, $file );
}

sub _RELATIVETOPICPATH {
    my ( $this, $params, $theTopic, $web ) = @_;
    my $topic = $params->{_DEFAULT};

    return '' unless $topic;

    my $theRelativePath;
    # if there is no dot in $topic, no web has been specified
    if ( index( $topic, '.' ) == -1 ) {
        # add local web
        $theRelativePath = $web . '/' . $topic;
    } else {
        $theRelativePath = $topic; #including dot
    }
    # replace dot by slash is not necessary; TWiki.MyTopic is a valid url
    # add ../ if not already present to make a relative file reference
    if ( $theRelativePath !~ m!^../! ) {
        $theRelativePath = "../$theRelativePath";
    }
    return $theRelativePath;
}

sub _ATTACHURLPATH {
    my ( $this, $params, $topic, $web ) = @_;
    return $this->getPubUrl(0, $web, $topic);
}

sub _ATTACHURL {
    my ( $this, $params, $topic, $web ) = @_;
    return $this->getPubUrl(1, $web, $topic);
}

sub _LANGUAGE {
    my $this = shift;
    return $this->{i18n}->language();
}

sub _LANGUAGES {
    my ( $this , $params ) = @_;
    my $format = $params->{format} || "   * \$langname";
    my $separator = $params->{separator} || "\n";
    $separator =~ s/\\n/\n/g;
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker = $params->{marker} || 'selected="selected"';

    # $languages is a hash reference:
    my $languages = $this->{i18n}->enabled_languages();

    my @tags = sort(keys(%{$languages}));

    my $result = '';
    my $i = 0; 
    foreach my $lang (@tags) {
         my $item = $format;
         my $name = ${$languages}{$lang};
         $item =~ s/\$langname/$name/g;
         $item =~ s/\$langtag/$lang/g;
         my $mark = ( $selection =~ / \Q$lang\E / ) ? $marker : '';
         $item =~ s/\$marker/$mark/g;
         $result .= $separator if $i;
         $result .= $item;
         $i++;
    }

    return $result;
}

sub _MAKETEXT {
    my( $this, $params ) = @_;

    my $str = $params->{_DEFAULT} || $params->{string} || "";
    return "" unless $str;

    # escape everything:
    $str =~ s/\[/~[/g;
    $str =~ s/\]/~]/g;

    # restore already escaped stuff:
    $str =~ s/~~\[/~[/g;
    $str =~ s/~~\]/~]/g;

    # unescape parameters and calculate highest parameter number:
    my $max = 0;
    $str =~ s/~\[(\_(\d+))~\]/ $max = $2 if ($2 > $max); "[$1]"/ge;
    $str =~ s/~\[(\*,\_(\d+),[^,]+(,([^,]+))?)~\]/ $max = $2 if ($2 > $max); "[$1]"/ge;

    # get the args to be interpolated.
    my $argsStr = $params->{args} || "";

    my @args = split (/\s*,\s*/, $argsStr) ;
    # fill omitted args with zeros
    while ((scalar @args) < $max) {
        push(@args, 0);
    }

    # do the magic:
    my $result  =  $this->{i18n}->maketext($str, @args);

    # replace accesskeys:
    $result =~ s#(^|[^&])&([a-zA-Z])#$1<span class='twikiAccessKey'>$2</span>#g;

    # replace escaped amperstands:
    $result =~ s/&&/\&/g;

    return $result;
}

sub _SCRIPTNAME {
    #my ( $this, $params, $theTopic, $theWeb ) = @_;
    # try SCRIPT_FILENAME
    my $value = $ENV{SCRIPT_FILENAME};
    if( $value ) {
        $value =~ s!.*/([^/]+)$!$1!o;
        return $value;
    }
    # try SCRIPT_URL (won't work with url rewriting)
    $value = $ENV{SCRIPT_URL};
    if( $value ) {
        # e.g. '/cgi-bin/view.cgi/TWiki/WebHome'
        # cut URL path to get 'view.cgi/TWiki/WebHome'
        $value =~ s|^$TWiki::cfg{ScriptUrlPath}/?||o;
        # cut extended path to get 'view.cgi'
        $value =~ s|/.*$||;
        return $value;
    }
    # no joy
    return '';
}

sub _SCRIPTURL {
    my ( $this, $params, $topic, $web ) = @_;
    my $script = $params->{_DEFAULT} || '';

    return $this->getScriptUrl( 1, $script );
}

sub _SCRIPTURLPATH {
    my ( $this, $params, $topic, $web ) = @_;
    my $script = $params->{_DEFAULT} || '';

    return $this->getScriptUrl( 0, $script );
}

sub _PUBURL {
    my $this = shift;
    return $this->getPubUrl(1);
}

sub _PUBURLPATH {
    my $this = shift;
    return $this->getPubUrl(0);
}

sub _ALLVARIABLES {
    return shift->{prefs}->stringify();
}

sub _META {
    my ( $this, $params, $topic, $web ) = @_;

    my $meta  = $this->inContext( 'can_render_meta' );

    return '' unless $meta;

    my $option = $params->{_DEFAULT};

    if( $option eq 'form' ) {
        # META:FORM and META:FIELD
        return TWiki::Form::renderForDisplay( $this->{templates}, $meta );
    } elsif ( $option eq 'formfield' ) {
        # a formfield from within topic text
        return $this->{renderer}->renderFormField( $meta, $params );
    } elsif( $option eq 'attachments' ) {
        # renders attachment tables
        return $this->{attach}->renderMetaData( $web, $topic, $meta, $params );
    } elsif( $option eq 'moved' ) {
        return $this->{renderer}->renderMoved( $web, $topic, $meta, $params );
    } elsif( $option eq 'parent' ) {
        return $this->{renderer}->renderParent( $web, $topic, $meta, $params );
    }

    return '';
}

# Remove NOP tag in template topics but show content. Used in template
# _topics_ (not templates, per se, but topics used as templates for new
# topics)
sub _NOP {
    my ( $this, $params, $topic, $web ) = @_;

    return '<nop>' unless $params->{_RAW};

    return $params->{_RAW};
}

# Shortcut to %TMPL:P{"sep"}%
sub _SEP {
    my $this = shift;
    return $this->{templates}->expandTemplate('sep');
}

#deprecated functionality, now implemented using %USERINFO%
#move to compatibility plugin in TWiki5
sub _WIKINAME_deprecated {
    my ( $this, $params ) = @_;
    ASSERT($this->isa( 'TWiki')) if DEBUG;

    $params->{format} = $this->{prefs}->getPreferencesValue( 'WIKINAME' ) ||
      '$wikiname';

    return $this->_USERINFO($params);
}
#deprecated functionality, now implemented using %USERINFO%
#move to compatibility plugin in TWiki5
sub _USERNAME_deprecated {
    my ( $this, $params ) = @_;
    ASSERT($this->isa( 'TWiki')) if DEBUG;

    $params->{format} = $this->{prefs}->getPreferencesValue( 'USERNAME' ) ||
      '$username';

    return $this->_USERINFO($params);
}
#deprecated functionality, now implemented using %USERINFO%
#move to compatibility plugin in TWiki5
sub _WIKIUSERNAME_deprecated {
    my ( $this, $params ) = @_;
    ASSERT($this->isa( 'TWiki')) if DEBUG;

    $params->{format} =
      $this->{prefs}->getPreferencesValue( 'WIKIUSERNAME' ) ||
        '$wikiusername';

    return $this->_USERINFO($params);
}

sub _USERINFO {
    my ( $this, $params ) = @_;
    my $format = $params->{format} || '$username, $wikiusername, $emails';
    my $userDebug = $params->{'userdebug'} || '';

    my $user = $this->{user};
    if( $params->{_DEFAULT} ) {
        $user = $this->{users}->findUser( $params->{_DEFAULT}, undef, 1 );
        return '' if !$user;
        return '' if( $TWiki::cfg{AntiSpam}{HideUserDetails} &&
                        !$this->{user}->isAdmin() &&
                          $user != $this->{user} );
    }

    my $info = $format;

    if ($info =~ /\$username/) {
        my $username = $user->login();
        $info =~ s/\$username/$username/g;
    }
    if ($info =~ /\$wikiname/) {
        my $wikiname = $user->wikiName();
        $info =~ s/\$wikiname/$wikiname/g;
    }
    if ($info =~ /\$wikiusername/) {
        my $wikiusername = $user->webDotWikiName();
        $info =~ s/\$wikiusername/$wikiusername/g;
    }
    if ($info =~ /\$emails/) {
        my $emails = join(', ', $user->emails());
        $info =~ s/\$emails/$emails/g;
    }
    if ($info =~ /\$groups/) {
        my @groupNames = map {$_->webDotWikiName();} $user->getGroups();
        my $groups = join(', ', @groupNames);
        $groups .= ' isAdmin()' if $user->isAdmin();
        $info =~ s/\$groups/$groups/g;
    }

    #don't give out userlists to non-admins
    if ($userDebug ne '' && $user->isAdmin()) {
        my $users = '';
        $users .= "\n\nLoaded Users: ".join(" \n", map {$_->webDotWikiName()} @{$this->{users}->getAllLoadedUsers()});
        $users .= "\n\nALL Users: ".join(" \n", map {$_->webDotWikiName()} @{$this->{users}->getAllUsers()});
        $info .=  $users;
    }

    return $info;
}

sub _GROUPS {
    my ( $this, $params ) = @_;

    my @groupNames = map {
      '| [['.$_->webDotWikiName().  ']['.$_->wikiName().']] |'.
        join(', ', map {
            '[['.$_->webDotWikiName().']['.$_->wikiName().']]'
        } @{$_->groupMembers()}). ' |';
    } sort {$a->wikiName() cmp $b->wikiName()} @{$this->{users}->getAllGroups()};

    return '| *Group* | *Members* |'."\n".join("\n", @groupNames);
}

1;
