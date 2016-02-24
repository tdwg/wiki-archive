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

=begin twiki

---+ package TWiki::Net

Object that brokers access to network resources.

=cut

package TWiki::Net;

use strict;
use Assert;
use TWiki::Time;
use TWiki::Sandbox;
use Error qw( :try );

use vars qw( $LWPavailable );

sub new {
    my ( $class, $session ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );

    $this->{session} = $session;
    $this->{mailHandler} = undef;

    return $this;
}

=pod

---++ ObjectMethod getUrl($protocol, $host, $port, $url, $user, $pass ) -> $text

Get the text at the other end of a URL

=cut

sub getUrl {
    my $this = shift;
    my $protocol = shift;

    if( $this->_LWPavailable()) {
        return $this->_getURLUsingLWP( $protocol, @_ );
    }

    # Fallback mechanism
    my( $host, $port, $url, $user, $pass ) = @_;
    die "LWP not available for reading https: URLs: $@"
      if( $protocol eq 'https');

    # Run-time use of Socket module when needed
    require Socket;
    import Socket qw(:all);

    $port ||= 80;
    $port =~ s/^://;

    my $result = '';
    $url = "/" unless( $url );
    my $req = "GET $url HTTP/1.0\r\n";

    $req .= "Host: $host:$port\r\n";
    if( $user && $pass ) {
        # Use MIME::Base64 at run-time if using outbound proxy with
        # authentication
        require MIME::Base64;
        import MIME::Base64 ();
        my $base64 = encode_base64( "$user:$pass", "\r\n" );
        $req .= "Authorization: Basic $base64";
    }

    my $prefs = $this->{session}->{prefs};
    my $proxyHost = $prefs->getPreferencesValue('PROXYHOST') ||
      $TWiki::cfg{PROXY}{HOST};
    my $proxyPort = $prefs->getPreferencesValue('PROXYPORT') ||
      $TWiki::cfg{PROXY}{PORT};
    if($proxyHost && $proxyPort) {
        $req = "GET http://$host:$port$url HTTP/1.0\r\n";
        $host = $proxyHost;
        $port = $proxyPort;
    }

    $req .= "\r\n\r\n";

    my ( $iaddr, $paddr, $proto );
    $iaddr   = inet_aton( $host );
    $paddr   = sockaddr_in( $port, $iaddr );
    $proto   = getprotobyname( 'tcp' );
    unless( socket( *SOCK, &PF_INET, &SOCK_STREAM, $proto ) ) {
        $this->{session}->writeWarning( "TWiki::Net::getUrl socket: $!" );
        return "content-type: text/plain\n\nERROR: TWiki::Net::getUrl socket: $!.";
    }
    unless( connect( *SOCK, $paddr ) ) {
        $this->{session}->writeWarning( "TWiki::Net::getUrl connect: $!" );
        return "content-type: text/plain\n\nERROR: TWiki::Net::getUrl connect: $!. \n$req";
    }
    select SOCK; $| = 1;
    print SOCK $req;
    while( <SOCK> ) { $result .= $_; }
    unless( close( SOCK ) ) {
        $this->{session}->writeWarning( "TWiki::Net::getUrl close: $!" );
    }
    select STDOUT;
    return $result;
}

sub _LWPavailable {
    unless( defined $LWPavailable ) {
        eval 'use LWP';
        $LWPavailable = !$@;
    }
    return $LWPavailable
}

sub _getURLUsingLWP {
    my( $this, $protocol, $host, $port, $path, $user, $pass ) = @_;

    $port ||= 80;
    $port =~ s/^://;
    my $request;
    require HTTP::Request;
    $request = HTTP::Request->new(GET => "$protocol://$host:$port$path");
    {
        package _UserCredAgent;
        @_UserCredAgent::ISA = qw(LWP::UserAgent);
        sub new {
            my $this = bless( new LWP::UserAgent(), $_[0] );
            $this->{user} = $_[1];
            $this->{pass} = $_[2];
            return $this;
        }
        sub get_basic_credentials {
            my($this, $realm, $uri) = @_;
            return ($this->{user}, $this->{pass});
        };
    };
    my $ua = new _UserCredAgent($user, $pass);
    my $response = $ua->request($request);
    return $response->as_string();
}

# pick a default mail handler
sub _installMailHandler {
    my $this = shift;
    my $handler = 0; # Not undef
    my $prefs = $this->{session}->{prefs};

    $this->{MAIL_HOST}  = $prefs->getPreferencesValue( 'SMTPMAILHOST' ) ||
      $TWiki::cfg{SMTP}{MAILHOST};
    $this->{HELLO_HOST} = $prefs->getPreferencesValue( 'SMTPSENDERHOST' ) ||
      $TWiki::cfg{SMTP}{SENDERHOST};


    if( $this->{MAIL_HOST} ) {
        # See Codev.RegisterFailureInsecureDependencyCygwin for why
        # this must be untainted
        $this->{MAIL_HOST} =
          TWiki::Sandbox::untaintUnchecked( $this->{MAIL_HOST} );
        eval {	# May fail if Net::SMTP not installed
            require Net::SMTP;
        };
        if( $@ ) {
            $this->{session}->writeWarning( "SMTP not available: $@" );
        } else {
            $handler = \&_sendEmailByNetSMTP;
        }
    }

    if( !$handler && $TWiki::cfg{MailProgram} ) {
        $handler = \&_sendEmailBySendmail;
    }

    $this->setMailHandler( $handler ) if $handler;
}

=pod

---++ setMailHandler( \&fn )

   * =\&fn= - reference to a function($) (see _sendEmailBySendmail for proto)
Install a handler function to take over mail sending from the default
SMTP or sendmail methods. This is provided mainly for tests that
need to be told when a mail is sent, without actually sending it. It
may also be useful in the event that someone needs to plug in an
alternative mail handling method.

=cut

sub setMailHandler {
    my( $this, $fnref ) = @_;
    $this->{mailHandler} = $fnref;
}

=pod

---++ ObjectMethod sendEmail ( $text, $retries ) -> $error

   * =$text= - text of the mail, including MIME headers
   * =$retries= - number of times to retry the send (default 1)

Send an email specified as MIME format content.
Date: ...\nFrom: ...\nTo: ...\nCC: ...\nSubject: ...\n\nMailBody...

=cut

sub sendEmail {
    my( $this, $text, $retries ) = @_;
    ASSERT($this->isa( 'TWiki::Net')) if DEBUG;
    $retries ||= 1;

    unless( defined $this->{mailHandler} ) {
        $this->_installMailHandler();
    }

    return 'No mail handler available' unless $this->{mailHandler};

    # Put in a Date header, mainly for Qmail
    my $dateStr = TWiki::Time::formatTime(time, '$email');
    $text = "Date: " . $dateStr . "\n" . $text;

    my $errors = '';
    my $back_off = 1; # seconds, doubles on each retry
    while ( $retries-- ) {
        try {
            &{$this->{mailHandler}}( $this, $text );
            $retries = 0;
        } catch Error::Simple with {
            my $e = shift->stringify();
            # be nasty to errors that we didn't throw. They may be
            # caused by SMTP or perl, and give away info about the
            # install that we don't want to share.
            unless( $e =~ /^ERROR/ ) {
                $this->{session}->writeWarning( $e );
                $e = "Mail could not be sent - see TWiki warning log.";
            }
            $errors .= $e."\n";
            sleep( $back_off );
            $back_off *= 2;
            $errors .= "Too many failures sending mail"
              unless $retries;
        };
    }
    return $errors;
}

sub _fixLineLength {
    my( $addrs ) = @_;
    # split up header lines that are too long
    $addrs =~ s/(.{60}[^,]*,\s*)/$1\n        /go;
    $addrs =~ s/\n\s*$//gos;
    return $addrs;
}

sub _sendEmailBySendmail {
    my( $this, $text ) = @_;

    # send with sendmail
    my ( $header, $body ) = split( "\n\n", $text, 2 );
    $header =~ s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1.$2.$3._fixLineLength($4)/geois;
    $text = "$header\n\n$body";   # rebuild message

    open( MAIL, '|'.$TWiki::cfg{MailProgram} ) ||
      die "ERROR: Can't send mail using TWiki::cfg{MailProgram}";
    print MAIL $text;
    close( MAIL );
    die "ERROR: Exit code $? from TWiki::cfg{MailProgram}" if $?;
}

sub _sendEmailByNetSMTP {
    my( $this, $text ) = @_;

    my $from = '';
    my @to = ();

    my ( $header, $body ) = split( "\n\n", $text, 2 );
    my @headerlines = split( /\r?\n/, $header );
    $header =~ s/\nBCC\:[^\n]*//os;  #remove BCC line from header
    $header =~ s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1 . $2 . $3 . _fixLineLength( $4 )/geois;
    $text = "$header\n\n$body";   # rebuild message

    # extract 'From:'
    my @arr = grep( /^From: /i, @headerlines );
    if( scalar( @arr ) ) {
        $from = $arr[0];
        $from =~ s/^From:\s*//io;
        $from =~ s/.*<(.*?)>.*/$1/o; # extract "user@host" out of "Name <user@host>"
    }
    unless( $from ) {
        # SMELL: should be a TWiki::inlineAlert
        die "ERROR: Can't send mail, missing 'From:'";
    }

    # extract @to from 'To:', 'CC:', 'BCC:'
    @arr = grep( /^To: /i, @headerlines );
    my $tmp = '';
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^To:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^CC: /i, @headerlines );
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^CC:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^BCC: /i, @headerlines );
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^BCC:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    if( ! ( scalar( @to ) ) ) {
        # SMELL: should be a TWiki::inlineAlert
        die "ERROR: Can't send mail, missing recipient";
    }

    return undef unless( scalar @to );

    # Change SMTP protocol recipient format from 
    # "User Name <userid@domain>" to "userid@domain"
    # for those SMTP hosts that need it just that way.
    foreach (@to) {
        s/^.*<(.*)>$/$1/;
    }

    my $smtp = 0;
    if( $this->{HELLO_HOST} ) {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST},
                                Hello => $this->{HELLO_HOST},
                                Debug => $TWiki::cfg{SMTP}{Debug} || 0 );
    } else {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST},
                                Debug => $TWiki::cfg{SMTP}{Debug} || 0 );
    }
    my $status = '';
    my $mess = "ERROR: Can't send mail using Net::SMTP. ";
    die $mess."Can't connect to '$this->{MAIL_HOST}'" unless $smtp;

    if( $TWiki::cfg{SMTP}{Username} ) {
        $smtp->auth($TWiki::cfg{SMTP}{Username}, $TWiki::cfg{SMTP}{Password});
    }
    $smtp->mail( $from ) || die $mess.$smtp->message;
    $smtp->to( @to, { SkipBad => 1 } ) || die $mess.$smtp->message;
    $smtp->data( $text ) || die $mess.$smtp->message;
    $smtp->dataend() || die $mess.$smtp->message;
    $smtp->quit();
}

1;
