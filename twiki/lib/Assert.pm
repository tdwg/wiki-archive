package Assert;

# Derived from Carp::Assert
# Copyright 2004 Crawford Currie
# Copyright 2002 by Michael G Schwern <schwern@pobox.com
# Slightly simplified derived version of Assert
# Differences are:
#  1. ASSERT instead of assert
#  2. has to be _explicitly enabled_ using the $ENV{ASSERT}
#  3. should and shouldnt have been removed
#  4. Added UNTAINTED
#
# Usage is as for Carp::Assert except that you have to explicitly
# enable asserts using the environment variable "TWIKI_ASSERTS"
# add ENV{TWIKI_ASSERTS} = 1; to you bin/setlib.cfg or bin/LocalLib.cfg
require 5.004;

use strict qw(subs vars);
use Exporter;

use vars qw(@ISA $VERSION %EXPORT_TAGS);

BEGIN {
    $VERSION = '0.18';

    @ISA = qw(Exporter);

    %EXPORT_TAGS = (
                    NDEBUG => [qw(ASSERT UNTAINTED affirm DEBUG)],
                   );
    $EXPORT_TAGS{DEBUG} = $EXPORT_TAGS{NDEBUG};
    Exporter::export_tags(qw(NDEBUG DEBUG));
}

# constant.pm, alas, adds too much load time (yes, I benchmarked it)
sub REAL_DEBUG  ()  { 1 }       # CONSTANT
sub NDEBUG      ()  { 0 }       # CONSTANT

# Export the proper DEBUG flag according to if TWIKI_ASSERTS is set,
# otherwise export noop versions of our routines
sub noop { undef }
sub noop_affirm (&;$) { undef };

sub import {
    if( $ENV{TWIKI_ASSERTS} ) {
        *DEBUG = *REAL_DEBUG;
        Assert->_export_to_level(1, @_);
    } else {
        my $caller = caller;
        foreach my $func (grep !/^DEBUG$/, @{$EXPORT_TAGS{'NDEBUG'}}) {
            if( $func eq 'affirm' ) {
                *{$caller.'::'.$func} = \&noop_affirm;
            } else {
                *{$caller.'::'.$func} = \&noop;
            }
        }
        *{$caller.'::DEBUG'} = \&NDEBUG;
    }
}


# 5.004's Exporter doesn't have export_to_level.
sub _export_to_level
{
      my $pkg = shift;
      my $level = shift;
      (undef) = shift;                  # XXX redundant arg
      my $callpkg = caller($level);
      $pkg->export($callpkg, @_);
}


sub unimport {
    *DEBUG = *NDEBUG;
    push @_, ':NDEBUG';
    goto &import;
}


# Can't call confess() here or the stack trace will be wrong.
sub _fail_msg {
    my($name) = shift;
    my $msg = 'Assertion';
    $msg   .= " ($name)" if defined $name;
    $msg   .= " failed!\n";
    return $msg;
}

sub ASSERT ($;$) {
    unless($_[0]) {
        require Carp;
        Carp::confess( _fail_msg($_[1]) );
    }
    return undef;
}

sub UNTAINTED($) {
    local(@_, $@, $^W) = @_;
    my $x;
    return( eval { $x = $_[0], kill 0; 1 } );
}

sub affirm (&;$) {
    unless( eval { &{$_[0]}; } ) {
        my $name = $_[1];

        if( !defined $name ) {
            eval {
                require B::Deparse;
                $name = B::Deparse->new->coderef2text($_[0]);
            };
            $name = 
              'code display non-functional on this version of Perl, sorry'
                if $@;
        }

        require Carp;
        Carp::confess( _fail_msg($name) );
    }
    return undef;
}

1;
