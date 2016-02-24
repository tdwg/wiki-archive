# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
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

---+ package TWiki::UI

Service functions used by the UI packages

=cut

package TWiki::UI;

use strict;
use Error qw( :try );
use Assert;
use CGI::Carp qw( fatalsToBrowser );
use CGI qw( :cgi -any );
use TWiki;
use TWiki::OopsException;

sub TRACE_PASSTHRU {
    # Change to a 1 to trace passthrough
    0;
};

=pod

---++ StaticMethod run( \&method, ... )

Entry point for execution of a UI function. The parameter is a
reference to the method.

... is a list of name-value pairs that define initial context identifiers
that must be set during initPlugin. This set will be extended to include
command_line if the script is detected as being run outside the browser.

=cut

sub run {
    my ( $method, %initialContext ) = @_;

    my ( $query, $pathInfo, $user, $url, $topic );

    # Use unbuffered IO
    $| = 1;

    # -------------- Only needed to work around an Apache 2.0 bug on Unix
    # OPTIONAL
    # If you are running TWiki on Apache 2.0 on Unix you might experience
    # TWiki scripts hanging forever. This is a known Apache 2.0 bug. A fix is 
    # available at http://issues.apache.org/bugzilla/show_bug.cgi?id=22030.
    # You are recommended to patch your Apache installation.
    #
    # As a workaround, uncomment ONE of the lines below. As a drawback,
    # errors will not be reported to the browser via CGI::Carp any more.

    # Opening STDERR here and not in the BEGIN block as some perl accelerators
    # close STDERR after each request so that we need to reopen it here again

    # open(STDERR, ">>/dev/null");      # throw away cgi script errors, or
    # open(STDERR, ">>$TWiki::cfg{DataDir}/error.log"); # redirect errors to a log file


    if( DEBUG || $TWiki::cfg{WarningsAreErrors} ) {
        # For some mysterious reason if this handler is defined
        # in 'new TWiki' it gets lost again before we get here
        $SIG{__WARN__} = sub { die @_; };
    }

    if( $ENV{'GATEWAY_INTERFACE'} ) {
        # script is called by browser
        $query = new CGI;

        if( $TWiki::cfg{DrainStdin} ) {
            # drain STDIN.  This may be necessary if the script is called
            # due to a redirect and the original query was a POST. In this
            # case the web server is waiting to write the POST data to
            # this script's STDIN, but CGI.pm won't drain STDIN as it is
            # seeing a GET because of the redirect, not a POST.  This script
            # tries to write to STDOUT, which goes back to the web server,
            # but the server isn't paying attention to that (as its waiting for
            # the script to _read_, not _write_), and everything blocks.
            # Some versions of apache seem to be more susceptible than others to
            # this.
            my $content_length =
                defined($ENV{'CONTENT_LENGTH'}) ? $ENV{'CONTENT_LENGTH'} : 0;
            read(STDIN, my $buf, $content_length, 0 ) if $content_length;
        }
        my $cache = $query->param('twiki_redirect_cache');
        if ($cache) {
            $cache = TWiki::Sandbox::untaintUnchecked($cache);
            # Read cached post parameters
            if (open(F, '<'.$cache)) {
                local $/;
                if (TRACE_PASSTHRU) {
                    print STDERR "Passthru: Loading cache for ",
                      $query->url(),'?',$query->query_string(),"\n";
                    print STDERR <F>,"\n";
                    close(F);
                    open(F, '<'.$cache);
                }
                $query = new CGI(\*F);
                close(F);
                unlink($cache);
                print STDERR "Passtrhru: Loaded and unlinked $cache\n"
                  if TRACE_PASSTHRU;
            } else {
                print STDERR "Passtrhru: Could not find $cache\n"
                  if TRACE_PASSTHRU;
            }
        }
    } else {
        # script is called by cron job or user
        $initialContext{command_line} = 1;

        $user = $TWiki::cfg{SuperAdminGroup};
        $query = new CGI();
        while( scalar( @ARGV )) {
            my $arg = shift( @ARGV );
            if ( $arg =~ /^-?([A-Za-z0-9_]+)$/o ) {
                my $name = $1;
                my $arg = TWiki::Sandbox::untaintUnchecked( shift( @ARGV ));
                if( $name eq 'user' ) {
                    $user = $arg;
                } else {
                    $query->param( -name => $name, -value => $arg );
                }
            } else {
                $query->path_info( TWiki::Sandbox::untaintUnchecked( $arg ));
            }
        }
    }

    my $session = new TWiki( $user, $query, \%initialContext );

    local $SIG{__DIE__} = \&Carp::confess;

    try {
        $session->{loginManager}->checkAccess();
        &$method( $session );
    } catch TWiki::AccessControlException with {
        my $e = shift;
        unless( $session->{loginManager}->forceAuthentication() ) {
            # Client did not want to authenticate, perhaps because
            # we are already authenticated.
            my $url = $session->getOopsUrl('accessdenied',
                                       def => 'topic_access',
                                       web => $e->{web},
                                       topic => $e->{topic},
                                       params => [ $e->{mode},
                                                   $e->{reason} ]);
            $session->redirect( $url, 1 );
        }

    } catch TWiki::OopsException with {
        my $e = shift;
        my $url = $session->getOopsUrl( $e );
        $session->redirect( $url, $e->{keep} );

    } catch Error::Simple with {
        my $e = shift;
        print "Content-type: text/plain\n\n";
        if( DEBUG ) {
            # output the full message and stacktrace to the browser
            print $e->stringify();
        } else {
            my $mess = $e->stringify();
            print STDERR $mess;
            $session->writeWarning( $mess );
            # tell the browser where to look for more help
            print 'TWiki detected an internal error - please check your TWiki logs and webserver logs for more information.'."\n\n";
            $mess =~ s/ at .*$//s;
            # cut out pathnames from public announcement
            $mess =~ s#/[\w./]+#path#g;
            print $mess;
        }
    } otherwise {
        print "Content-type: text/plain\n\n";
        print "Unspecified error";
    };

    $session->finish();
}

=pod twiki

---++ StaticMethod checkWebExists( $session, $web, $topic, $op )

Check if the web exists. If it doesn't, will throw an oops exception.
 $op is the user operation being performed.

=cut

sub checkWebExists {
    my ( $session, $webName, $topic, $op ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    unless ( $session->{store}->webExists( $webName ) ) {
        throw
          TWiki::OopsException( 'accessdenied',
                                def => 'no_such_web',
                                web => $webName,
                                topic => $topic,
                                params => $op );
    }
}

=pod

---++ StaticMethod topicExists( $session, $web, $topic, $op ) => boolean

Check if the given topic exists, throwing an OopsException
if it doesn't. $op is the user operation being performed.

=cut

sub checkTopicExists {
    my ( $session, $webName, $topic, $op ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    unless( $session->{store}->topicExists( $webName, $topic )) {
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'no_such_topic',
                                    web => $webName,
                                    topic => $topic,
                                    params => $op );
    }
}

=pod twiki

---++ StaticMethod checkMirror( $session, $web, $topic )

Checks if this web is a mirror web, throwing an OopsException
if it is.

=cut

sub checkMirror {
    my ( $session, $webName, $topic ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    my( $mirrorSiteName, $mirrorViewURL ) =
      $session->readOnlyMirrorWeb( $webName );

    return unless ( $mirrorSiteName );

    throw TWiki::OopsException( 'mirror',
                                web => $webName,
                                topic => $topic,
                                params => [ $mirrorSiteName,
                                            $mirrorViewURL ] );
}

=pod twiki

---++ StaticMethod checkAccess( $web, $topic, $mode, $user )

Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a TWiki::OopsException if not.

=cut

sub checkAccess {
    my ( $session, $web, $topic, $mode, $user ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    unless( $session->{security}->checkAccessPermission(
        $mode, $user, undef, undef, $topic, $web )) {
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'topic_access',
                                    web => $web,
                                    topic => $topic,
                                    params =>
                                    [ $mode,
                                      $session->{security}->getReason()]);
    }
}

=pod

---++ StaticMethod readTemplateTopic( $session, $theTopicName ) -> ( $meta, $text )

Read a topic from the TWiki web, or if that fails from the current
web.

=cut

sub readTemplateTopic {
    my( $session, $theTopicName ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    $theTopicName =~ s/$TWiki::cfg{NameFilter}//go;

    my $web = $TWiki::cfg{SystemWebName};
    if( $session->{store}->topicExists( $session->{webName}, $theTopicName )) {
        # try to read from current web, if found
        $web = $session->{webName};
    }
    return $session->{store}->readTopic(
        $session->{user}, $web, $theTopicName, undef );
}

1;
