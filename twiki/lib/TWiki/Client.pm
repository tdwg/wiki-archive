# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2005 Garage Games
# Copyright (C) 2005 Crawford Currie http://c-dot.co.uk
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

---+ package TWiki::Client

The package is also a Factory for login managers and also the base class
for all login managers.

On it's own, an object of this class is used when you specify 'none' in
the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. When it is used,
logins are not supported. If you want to authenticate users then you should
consider TemplateLogin or ApacheLogin, which are subclasses of this class.

If you are building a new login manager, then you should write a new subclass
of this class, implementing the methods marked as *VIRTUAL*. There are already
examples in the =lib/TWiki/Client= directory.

The class has extensive tracing, which is enabled by
$TWiki::cfg{Trace}{Client.pm}. The tracing is done in such a way as to
let the perl optimiser optimise out the trace function as a no-op if tracing
is disabled.

Here's an overview of how it works:

Early in TWiki::new, the login manager is created. The creation of the login manager does two things:
   1 If sessions are in use, it loads CGI::Session but doesn't initialise the session yet.
   1 Creates the login manager object
Slightly later in TWiki::new, loginManager->loadSession is called.
   1 Calls loginManager->getUser to get the username *before* the session is created
      * TWiki::Client::ApacheLogin looks at REMOTE_USER
      * TWiki::Client::TemplateLogin just returns undef
   1 reads the TWIKISID cookie to get the SID (or the TWIKISID parameters in the CGI query if cookies aren't available, or IP2SID mapping if that's enabled).
   1 Creates the CGI::Session object, and the session is thereby read.
   1 If the username still isn't known, reads it from the cookie. Thus TWiki::Client::ApacheLogin overrides the cookie using REMOTE_USER, and TWiki::Client::TemplateLogin *always* uses the session.

Later again in TWiki::new, plugins are given a chance to *override* the username found from the loginManager.

The last step in TWiki::new is to find the user, using whatever user mapping manager is in place.

---++ ObjectData =twiki=

The TWiki object this login manager is attached to.

=cut

package TWiki::Client;

use strict;
use Assert;
use Error qw( :try );
use TWiki;
use TWiki::Sandbox;

BEGIN {
    # suppress stupid warning in CGI::Cookie
    if ( exists $ENV{MOD_PERL} ) {
        if ( !defined( $ENV{MOD_PERL_API_VERSION} )) {
            $ENV{MOD_PERL_API_VERSION} = 1;
        }
    }
}

# Marker chars
use vars qw( $M1 $M2 $M3 );
$M1 = chr(5);
$M2 = chr(6);
$M3 = chr(7);

=pod

---++ StaticMethod makeLoginManager( $twiki ) -> $TWiki::Client

Factory method, used to generate a new TWiki::Client object
for the given session.

=cut

sub makeLoginManager {
    my $twiki = shift;
    ASSERT($twiki->isa( 'TWiki')) if DEBUG;

    if( $TWiki::cfg{UseClientSessions} &&
          !$twiki->inContext( 'command_line' )) {

        my $use = 'use CGI::Session';
        if( $TWiki::cfg{Sessions}{UseIPMatching} ) {
            $use .= ' qw(-ip-match)';
        }
        $use .= '; use CGI::Cookie';
        eval $use;
        throw Error::Simple( $@ ) if $@;

        # modified by RSP: get cookie name from config (TDWG SSO)
        if( $CGI::Session::VERSION eq "4.10" ) {
            # 4.10 is broken; see Item1989
            #$CGI::Session::NAME = 'fe_typo_user';
            $CGI::Session::NAME = 'TWiki';
        } else {
            #CGI::Session->name( 'fe_typo_user' );
            CGI::Session->name( 'TWiki' );
        }
    }

    my $mgr;
    if( $TWiki::cfg{LoginManager} eq 'none' ) {
        # No login manager; just use default behaviours
        $mgr = new TWiki::Client( $twiki );
    } else {
        eval 'use '. $TWiki::cfg{LoginManager};
        throw Error::Simple( $@ ) if $@;
        $mgr = $TWiki::cfg{LoginManager}->new( $twiki );
    }
    return $mgr;
}

# protected: Construct new client object.

sub new {
    my ( $class, $twiki ) = @_;
    my $this = bless( {}, $class );
    ASSERT($twiki->isa( 'TWiki')) if DEBUG;
    $this->{twiki} = $twiki;
    $twiki->leaveContext( 'can_login' );
    $this->{_cookies} = [];
    map{ $this->{_authScripts}{$_} = 1; }
      split( /[\s,]+/, $TWiki::cfg{AuthScripts} );

    # register tag handlers and values
    TWiki::registerTagHandler('LOGINURL', \&_LOGINURL);
    TWiki::registerTagHandler('LOGIN', \&_LOGIN);
    TWiki::registerTagHandler('LOGOUT', \&_LOGOUT);
    TWiki::registerTagHandler('SESSION_VARIABLE', \&_SESSION_VARIABLE);
    TWiki::registerTagHandler('AUTHENTICATED', \&_AUTHENTICATED);
    TWiki::registerTagHandler('CANLOGIN', \&_CANLOGIN);

    return $this;
}

sub _real_trace {
    my( $this, $mess ) = @_;
    my $id = 'Session'.
      ($this->{_cgisession} ? $this->{_cgisession}->id() : 'unknown');
    $id .= '(c)' if $this->{_haveCookie};
    print STDERR "$id: $mess\n";
}

if( $TWiki::cfg{Trace}{Client} ) {
    *_trace = \&_real_trace;
} else {
    *_trace = sub { undef };
}

# read/write IP to SID map, return SID
sub _IP2SID {
    my( $sid ) = @_;

    my $ip = $ENV{'REMOTE_ADDR'};

    return undef unless $ip; # no IP address, can't map

    my %ips;
    if( open( IPMAP, '<', $TWiki::cfg{Sessions}{Dir}.'/ip2sid' )) {
        local $/ = undef;
        %ips = map { split( /:/, $_ ) } split( /\r?\n/, <IPMAP> );
        close(IPMAP);
    }
    if( $sid ) {
        # known SID, map the IP addr to it
        $ips{$ip} = $sid;
        open( IPMAP, '>', $TWiki::cfg{Sessions}{Dir}.'/ip2sid') ||
          die "Failed to open ip2sid map for write. Ask your administrator to make sure that the {Sessions}{Dir} is writable by the webserver user.";
        print IPMAP map { "$_:$ips{$_}\n" } keys %ips;
        close(IPMAP);
    } else {
        # Return the SID for this IP address
        $sid = $ips{$ip};
    }
    return $sid;
}

=pod

---++ ObjectMethod loadSession($defaultUser) -> $login

Get the client session data, using the cookie and/or the request URL.
Set up appropriate session variables in the twiki object and return
the login name.

$defaultUser is a username to use if one is not available from other
sources. The username passed when you create a TWiki instance is
passed in here.

=cut

sub loadSession {
    my ($this, $defaultUser) = @_;
    my $twiki = $this->{twiki};

    # Try and get the user from the webserver
    my $authUser = $this->getUser( $this ) || $defaultUser;

    unless( $TWiki::cfg{UseClientSessions} ) {
        $this->userLoggedIn( $authUser ) if $authUser;
        return $authUser;
    }

    return $authUser if $twiki->inContext( 'command_line' );

    my $query = $twiki->{cgiQuery};

    $this->{_haveCookie} = $query->raw_cookie();

    _trace($this, "URL ".$query->url());
    if( $this->{_haveCookie} ) {
        _trace($this, "Cookie ".$this->{_haveCookie});
    } else {
        _trace($this, "No cookie ");
    }

    # First, see if there is a cookied session, creating a new session
    # if necessary.
    if( $TWiki::cfg{Sessions}{MapIP2SID} ) {
        # map the end user IP address to SID
        my $sid = _IP2SID();
        if( $sid ) {
            $this->{_cgisession} = CGI::Session->new(
                undef, $sid, { Directory => $TWiki::cfg{Sessions}{Dir} } );
        } else {
            $this->{_cgisession} = CGI::Session->new(
                undef, undef,
                { Directory => $TWiki::cfg{Sessions}{Dir} } );
            _trace($this, "New IP2SID session");
            _IP2SID( $this->{_cgisession}->id() );
        }
    } else {
        $this->{_cgisession} = CGI::Session->new(
            undef, $query,
            { Directory => $TWiki::cfg{Sessions}{Dir} } );
    }

    die CGI::Session->errstr() unless $this->{_cgisession};
    _trace($this, "Opened session");

    if( $authUser ) {
        _trace($this, "Webserver says user is $authUser");
    } else {
        $authUser = TWiki::Sandbox::untaintUnchecked(
            $this->{_cgisession}->param( 'AUTHUSER' ));
    }

#    # added by RSP: try to get logged in user from Typo3 website
#    # disabled because of overhead of calling Typo3 website everytime
#    if (!$authUser) {
#	my $_sessionId = $this->{_cgisession}->id();
#	$authUser = TWiki::Client::_typo3LoggedInUser($_sessionId);
#	$this->{_cgisession}->param( 'AUTHUSER', $authUser );
#	$this->{_cgisession}->param( 'VALIDATION', 1 );
#    }
 
    # if we couldn't get the login manager or the http session to tell
    # us who the user is, then let's use the CGI "remote user"
    # variable (which may have been set manually by a unit test,
    # or it might have come from Apache).
    if( $authUser ) {
        _trace($this, "Session says user is $authUser");
    } else {
        # Use remote user provided from "new TWiki" call. This is mainly
        # for testing.
        $authUser = $defaultUser;
        _trace($this, "TWiki object says user is $authUser") if $authUser;
    }

    $authUser ||= $defaultUser;

    # is this a logout?
    if( $query && $query->param( 'logout' ) ) {
        _trace($this, "User is logging out");
        
        # added by RSP: log out from Typo3 as well
        $this->_logOutOfTypo3($this->{_cgisession}->id());
        
        my $origurl = $ENV{HTTP_REFERER} || $query->url().$query->path_info();
        $this->redirectCgiQuery( $query, $origurl );
        $authUser = undef;
    }

    $this->userLoggedIn( $authUser );

    $twiki->{SESSION_TAGS}{SESSIONID} = $this->{_cgisession}->id();
    $twiki->{SESSION_TAGS}{SESSIONVAR} = $CGI::Session::NAME;

    return $authUser;
}

=pod

---++ ObjectMethod checkAccess()

Check if the script being run in this session is authorised for execution.
If not, throw an access control exception.

=cut

sub checkAccess {

    return unless( $TWiki::cfg{UseClientSessions} );

    my $this = shift;
    my $twiki = $this->{twiki};

    return undef if $twiki->inContext( 'command_line' );

    unless( $twiki->inContext( 'authenticated' ) ||
              $TWiki::cfg{LoginManager} eq 'none' ) {
        my $script = $ENV{'SCRIPT_NAME'} || $ENV{'SCRIPT_FILENAME'};
        $script =~ s@^.*/([^./]+)@$1@g if $script;

        if( defined $script && $this->{_authScripts}{$script} ) {
            my $topic = $this->{twiki}->{topicName};
            my $web = $this->{twiki}->{webName};
            throw TWiki::AccessControlException(
                $script, $this->{twiki}->{user}, $web, $topic,
                'authentication required' );
        }
    }
}

=pod

---++ ObjectMethod finish

Complete processing after the client's HTTP request has been responded
to. Flush the user's session (if any) to disk.

=cut

sub finish {
    my $this = shift;

    if( $this->{_cgisession} ) {
        $this->{_cgisession}->flush();
        die $this->{_cgisession}->errstr()
          if $this->{_cgisession}->errstr();
        _trace($this, "Flushed");
    }

    return unless( $TWiki::cfg{Sessions}{ExpireAfter} > 0 );

    expireDeadSessions();
}

=pod

---++ StaticMethod expireDeadSessions()

Delete sessions and passthrough files that are sitting around but are really expired.
This *assumes* that the sessions are stored as files.

This is a static method, but requires TWiki::cfg. It is designed to be
run from a session or from a cron job.

=cut

sub expireDeadSessions {
	my $time = time() || 0;
    my $exp = $TWiki::cfg{Sessions}{ExpireAfter} || 36000; # 10 hours
    $exp = -$exp if $exp < 0;

	opendir(D, $TWiki::cfg{Sessions}{Dir}) || return;
	foreach my $file ( grep { /^(passthru|cgisess)_[0-9a-f]{32}/ } readdir(D) ) {
        $file = TWiki::Sandbox::untaintUnchecked(
            $TWiki::cfg{Sessions}{Dir}.'/'.$file );
		my @stat = stat( $file );
        # Kill old files.
		# Ignore tiny new files. They can't be complete sessions.
        if( defined($stat[7]) ) {
            my $lat = $stat[8] || $stat[9] || $stat[10] || 0;
            unlink $file if( $time - $lat >= $exp );
            next;
		}

        # Just kill passthru files
        next if $file =~ /^passthru_/;

		open(F, $file) || next;
		my $session = <F>;
		close F;

        # SMELL: security hazard?
        $session = TWiki::Sandbox::untaintUnchecked( $session );

        my $D;
		eval $session;
		next if ( $@ );
        # The session is expired if it is empty, hasn't been accessed in ages
        # or has exceeded its registered expiry time.
        if( !$D || $time >= $D->{_SESSION_ATIME} + $exp ||
              $D->{_SESSION_ETIME} && $time >= $D->{_SESSION_ETIME} ) {
            unlink( $file );
            next;
        }
	}
	closedir D;
}

=pod

---++ ObjectMethod userLoggedIn( $login, $wikiname)

Called when the user logs in. It's invoked from TWiki::UI::Register::finish
for instance, when the user follows the link in their verification email
message.
   * =$login= - string login name
   * =$wikiname= - string wikiname

=cut

sub userLoggedIn {
    my( $this, $authUser, $wikiName ) = @_;

    my $twiki = $this->{twiki};
    return undef if $twiki->inContext( 'command_line' );

    if( $TWiki::cfg{UseClientSessions} ) {
        # create new session if necessary
        unless( $this->{_cgisession} ) {
            $this->{_cgisession} =
              CGI::Session->new(
                  undef, $twiki->{cgiQuery},
                  { Directory => $TWiki::cfg{Sessions}{Dir} } );
            die CGI::Session->errstr() unless $this->{_cgisession};
        }
    }
    if( $authUser && $authUser ne $TWiki::cfg{DefaultUserLogin} ) {
        _trace($this, "Session is authenticated");
        $this->{_cgisession}->param( 'AUTHUSER', $authUser )
          if( $TWiki::cfg{UseClientSessions} );
        $twiki->enterContext( 'authenticated' );
    } else {
        _trace($this, "Session is NOT authenticated");
        # if we are not authenticated, expire any existing session
        $this->{_cgisession}->clear( [ 'AUTHUSER' ] )
          if( $TWiki::cfg{UseClientSessions} );
        $twiki->leaveContext( 'authenticated' );
    }
    if( $TWiki::cfg{UseClientSessions} ) {
        # flush the session, to try to fix Item1820 and Item2234
        $this->{_cgisession}->flush();
        die $this->{_cgisession}->errstr() if $this->{_cgisession}->errstr();
        _trace($this, "Flushed");
    }
}

# get an RE that matches a local script URL
sub _myScriptURLRE {
    my $this = shift;

    my $s = $this->{_MYSCRIPTURL};
    unless( $s ) {
        $s = quotemeta($this->{twiki}->getScriptUrl( 1, $M1, $M2, $M3 ));
        $s =~ s@\\$M1@[^/]*?@go;
        $s =~ s@\\$M2@[^/]*?@go;
        $s =~ s@\\$M3@[^#\?/]*@go;
        # now add alternates for the various script-specific overrides
        foreach my $v ( values %{$TWiki::cfg{ScriptUrlPaths}} ) {
            my $over = $v;
            # escape non-alphabetics
            $over =~ s/(\W)/\\$1/g;
            $s .= '|'.$over;
        }
        $this->{_MYSCRIPTURL} = "($s)";
    }
    return $s;
}

# Rewrite a URL inserting the session id
sub _rewriteURL {
    my( $this, $url ) = @_;

    return $url unless $url;

    my $sessionId = $this->{_cgisession}->id();
    return $url unless $sessionId;
    return $url if $url =~ m/\?$CGI::Session::NAME=/;

    my $s = $this->_myScriptURLRE();

    # If the URL has no colon in it, or it matches the local script
    # URL, it must be an internal URL and therefore needs the session.
    if( $url !~ /:/ || $url =~ /^$s/ ) {

        # strip off existing params
        my $params = "?$CGI::Session::NAME=$sessionId";
        if( $url =~ s/\?(.*)$// ) {
            $params .= ';'.$1;
        }

        # strip off the anchor
        my $anchor = '';
        if( $url =~ s/(#.*)// ) {
            $anchor = $1;
        }

        # rebuild the URL
        $url .= $anchor.$params;
    } # otherwise leave it untouched

    return $url;
}

# Catch all FORMs and add a hidden Session ID variable.
# Only do this if the form is pointing to an internal link.
# This occurs if there are no colons in its target, if it has
# no target, or if its target matches a getScriptUrl URL.
# '$rest' is the bit of the initial form tag up to the closing >
sub _rewriteFORM {
    my( $this, $url, $rest ) = @_;

    return $url.$rest unless $this->{_cgisession};

    my $s = $this->_myScriptURLRE();

    if( $url !~ /:/ || $url =~ /^($s)/ ) {
        $rest .= CGI::hidden( -name => $CGI::Session::NAME,
                              -value => $this->{_cgisession}->id());
    }
    return $url.$rest;
}

=pod

---++ ObjectMethod endRenderingHandler()

This handler is called by getRenderedVersion just before the plugins
postRenderingHandler. So it is passed all HTML text just before it is
printed.

*DEPRECATED* Use postRenderingHandler instead.

=cut

sub endRenderingHandler {
    return unless( $TWiki::cfg{UseClientSessions} );

    my $this = shift;
    return undef if $this->{twiki}->inContext( 'command_line' );

    # If cookies are not turned on and transparent CGI session IDs are,
    # grab every URL that is an internal link and pass a CGI variable
    # with the session ID
    unless( $this->{_haveCookie} || !$TWiki::cfg{Sessions}{IDsInURLs} ) {
        # rewrite internal links to include the transparent session ID
        # Doesn't catch Javascript, because there are just so many ways
        # to generate links from JS.
        # SMELL: this would probably be done better using javascript
        # that handles navigation away from this page, and uses the
        # rules to rewrite any relative URLs at that time.

        # a href= rewriting
        $_[0] =~ s/(<a[^>]*(?<=\s)href=(["']))(.*?)(\2)/$1.$this->_rewriteURL($3).$4/geoi;

        # form action= rewriting
        # SMELL: Forms that have no target are also implicit internal
        # links, but are not handled. Does this matter>
        $_[0] =~ s/(<form[^>]*(?<=\s)(?:action)=(["']))(.*?)(\2[^>]*>)/$1.$this->_rewriteFORM($3, $4)/geoi;
    }

    # And, finally, the logon stuff
    $_[0] =~ s/%SESSIONLOGON%/$this->_dispLogon()/geo;
    $_[0] =~ s/%SKINSELECT%/$this->_skinSelect()/geo;
}

=pod

---++ ObjectMethod addCookie($c)

Add a cookie to the list of cookies for this session.
   * =$c= - a CGI::Cookie

=cut

sub addCookie {
    return unless( $TWiki::cfg{UseClientSessions} );

    my( $this, $c ) = @_;
    return undef if $this->{twiki}->inContext( 'command_line' );
    ASSERT($c->isa('CGI::Cookie')) if DEBUG;

    push( @{$this->{_cookies}}, $c );
}

=pod

---++ ObjectMethod modifyHeader( \%header )

Modify a HTTP header
   * =\%header= - header entries

=cut

sub modifyHeader {
    my( $this, $hopts ) = @_;

    return unless $this->{_cgisession};
    return if $TWiki::cfg{Sessions}{MapIP2SID};

    # modified by RSP: set domain using value defined in config (TDWG SSO)
    # needed so that servers on the same base domain share session cookies
    my $query = $this->{twiki}->{cgiQuery};
    my $c = CGI::Cookie->new( -name => $CGI::Session::NAME,
                              -value => $this->{_cgisession}->id(),
			      -domain =>  $TWiki::cfg{CookieDomain},
                              -path => '/' );

    push( @{$this->{_cookies}}, $c );
    $hopts->{cookie} = $this->{_cookies};
}

=pod

---++ ObjectMethod redirectCgiQuery( $url )

Generate an HTTP redirect on STDOUT, if you can. Return 1 if you did.
   * =$url= - target of the redirection.

=cut

sub redirectCgiQuery {

    my( $this, $query, $url ) = @_;

    if( $this->{_cgisession} ) {
        $url = $this->_rewriteURL( $url )
          unless( !$TWiki::cfg{Sessions}{IDsInURLs} || $this->{_haveCookie} );

        # This usually won't be important, but just in case they haven't
        # yet received the cookie and happen to be redirecting, be sure
        # they have the cookie. (this is a lot more important with
        # transparent CGI session IDs, because the session DIES when those
        # people go across a redirect without a ?CGISESSID= in it... But
        # EVEN in that case, they should be redirecting to a URL that
        # already *HAS* a sessionID in it... Maybe...)
        #
        # So this is just a big fat precaution, just like the rest of this
        # whole handler.

	# modified by RSP: set domain using value defined in config (TDWG SSO)
	# needed so that servers on the same base domain share session cookies
        my $cookie = CGI::Cookie->new( -name => $CGI::Session::NAME,
                                       -value => $this->{_cgisession}->id(),
				       -domain =>  $TWiki::cfg{CookieDomain},
                                       -path => '/' );
        push( @{$this->{_cookies}}, $cookie );
    }

    if( $TWiki::cfg{Sessions}{MapIP2SID} ) {
        _trace($this, "Redirect to $url WITHOUT cookie");
        print $query->redirect( -url => $url );
    } else {
        _trace($this, "Redirect to $url with cookie");
        print $query->redirect( -url => $url, -cookie => $this->{_cookies} );
    }

    return 1;
}

=pod

---++ ObjectMethod getSessionValues() -> \%values

Get a name->value hash of all the defined session variables

=cut

sub getSessionValues {
    my( $this ) = @_;

    return undef unless $this->{_cgisession};

    return $this->{_cgisession}->param_hashref();
}

=pod

---++ ObjectMethod getSessionValue( $name ) -> $value

Get the value of a session variable.

=cut

sub getSessionValue {
    my( $this, $key ) = @_;
    return undef unless $this->{_cgisession};

    return $this->{_cgisession}->param( $key );
}

=pod

---++ ObjectMethod setSessionValue( $name, $value )

Set the value of a session variable.
We do not allow setting of AUTHUSER.

=cut

sub setSessionValue {
    my( $this, $key, $value ) = @_;

    # We do not allow setting of AUTHUSER.
    if( $this->{_cgisession} &&
          $key ne 'AUTHUSER' &&
            defined( $this->{_cgisession}->param( $key, $value ))) {
        return 1;
    }

    return undef;
}

=pod

---++ ObjectMethod clearSessionValue( $name ) -> $boolean

Clear the value of a session variable.
We do not allow setting of AUTHUSER.

=cut

sub clearSessionValue {
    my( $this, $key ) = @_;

    # We do not allow clearing of AUTHUSER.
    if( $this->{_cgisession} &&
          $key ne 'AUTHUSER' &&
            defined( $this->{_cgisession}->param( $key ))) {
        $this->{_cgisession}->clear( [ $_[1] ] );

        return 1;
    }

    return undef;
}

=pod

---++ ObjectMethod forceAuthentication() -> boolean

*VIRTUAL METHOD* implemented by subclasses

Triggered by an access control violation, this method tests
to see if the current session is authenticated or not. If not,
it does whatever is needed so that the user can log in, and returns 1.

If the user has an existing authenticated session, the function simply drops
though and returns 0.

=cut

sub forceAuthentication {
    return 0;
}

=pod

---++ ObjectMethod loginUrl( ... ) -> $url

*VIRTUAL METHOD* implemented by subclasses

Return a full URL suitable for logging in.
   * =...= - url parameters to be added to the URL, in the format required by TWiki::getScriptUrl()

=cut

sub loginUrl {
    return '';
}

=pod

---++ ObjectMethod getUser()

*VIRTUAL METHOD* implemented by subclasses

If there is some other means of getting a username - for example,
Apache has remote_user() - then return it. Otherwise, return undef and
the username stored in the session will be used.

=cut

sub getUser {
    return undef;
}

sub _LOGIN {
    #my( $twiki, $params, $topic, $web ) = @_;
    my $twiki = shift;
    my $this = $twiki->{loginManager};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    return '' if $twiki->inContext( 'authenticated' );

    my $url = $this->loginUrl();
    if( $url ) {
        my $text = $twiki->{templates}->expandTemplate('LOG_IN');
        return CGI::a( { href=>$url }, $text );
    }
    return '';
}

sub _LOGOUTURL {
    my( $twiki, $params, $topic, $web ) = @_;
    my $this = $twiki->{loginManager};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    return $twiki->getScriptUrl(
        0, 'view',
        $twiki->{SESSION_TAGS}{BASEWEB},
        $twiki->{SESSION_TAGS}{BASETOPIC},
        'logout' => 1 );
}

sub _LOGOUT {
    my( $twiki, $params, $topic, $web ) = @_;
    my $this = $twiki->{loginManager};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    return '' unless $twiki->inContext( 'authenticated' );

    my $url = _LOGOUTURL( @_ );
    if( $url ) {
        my $text = $twiki->{templates}->expandTemplate('LOG_OUT');
        return CGI::a( {href=>$url }, $text );
    }
    return '';
}

sub _AUTHENTICATED {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{loginManager};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    if( $twiki->inContext( 'authenticated' )) {
        return $params->{then} || 1;
    } else {
        return $params->{else} || 0;
    }
}

sub _CANLOGIN {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{loginManager};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    if( $twiki->inContext( 'can_login' )) {
        return $params->{then} || 1;
    } else {
        return $params->{else} || 0;
    }
}

sub _SESSION_VARIABLE {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{loginManager};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    my $name = $params->{_DEFAULT};

    if( defined( $params->{set} ) ) {
        $this->setSessionValue( $name, $params->{set} );
        return '';
    } elsif( defined( $params->{clear} )) {
        $this->clearSessionValue( $name );
        return '';
    } else {
        return $this->getSessionValue( $name ) || '';
    }
}

sub _LOGINURL {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{loginManager};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    return $this->loginUrl();
}

sub _dispLogon {
    my $this = shift;

    return '' unless $this->{_cgisession};

    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};
    my $sessionId = $this->{_cgisession}->id();

    my $urlToUse = $this->loginUrl();

    unless( $this->{_haveCookie} || !$TWiki::cfg{Sessions}{IDsInURLs} ) {
        $urlToUse = $this->_rewriteURL( $urlToUse );
    }

    my $text = $twiki->{templates}->expandTemplate('LOG_IN');
    return CGI::a({ class => 'twikiAlert', href => $urlToUse }, $text );
}

sub _skinSelect {
    my $this = shift;
    my $twiki = $this->{twiki};
    my $skins = $twiki->{prefs}->getPreferencesValue('SKINS');
    my $skin = $twiki->getSkin();
    my @skins = split( /,/, $skins );
    unshift( @skins, 'default' );
    my $options = '';
    foreach my $askin ( @skins ) {
        $askin =~ s/\s//go;
        if( $askin eq $skin ) {
            $options .= CGI::option(
                { selected => 'selected', name => $askin }, $askin );
        } else {
            $options .= CGI::option( { name => $askin }, $askin );
        }
    }
    return CGI::Select( { name => 'stickskin' }, $options );
}


# added by RSP to implement TDWG SSO
sub _logOutOfTypo3 {
    my( $this, $sessionId ) = @_;

    use LWP::UserAgent;

    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar( {} );

    $ua->agent("Perl LWP::UserAgent");

    my $url = $TWiki::cfg{Typo3Url};

    my $response = $ua->post( $url,
      [ 'pid' => '531',
        'logintype' => 'logout',
        'submit' => 'LOGOUT',
        'twiki_sso' => '1',
        'effective_remote_addr' => $ENV{'REMOTE_ADDR'},
        'effective_remote_user_agent' => $ENV{'HTTP_USER_AGENT'},
        ],
      'Cookie' => $CGI::Session::NAME.'='.$sessionId
    );
}

sub _typo3LoggedInUser {
    my( $sessionId ) = @_;
    
    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar( {} );

    $ua->agent("Perl LWP::UserAgent");

    my $url = $TWiki::cfg{Typo3Url}; 

    my $response = $ua->post( $url,
      [
       'pid' => '531',
       'twiki_sso' => '1',
       'effective_remote_addr' => $ENV{'REMOTE_ADDR'},
       'effective_remote_user_agent' => $ENV{'HTTP_USER_AGENT'},
       ],
      'Cookie' => $CGI::Session::NAME.'='.$sessionId
    );

    # parse out logged in user name
    if( $response->content =~ m{Logged in as <strong>(\w+)</strong>} ) {
	return $1;

    } else {
	return undef;
    }
}


1;
