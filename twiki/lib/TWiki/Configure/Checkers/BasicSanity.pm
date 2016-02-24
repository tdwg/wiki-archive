#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
#
use strict;

package TWiki::Configure::Checkers::BasicSanity;

use base 'TWiki::Configure::Checker';

sub new {
    my ($class, $item) = @_;
    my $this = $class->SUPER::new($item);
    $this->{LocalSiteDotCfg} = undef;
    $this->{errors} = 0;

    return $this;
}

# return true if we have fatal errors
sub insane() {
    my $this = shift;
    return $this->{errors};
}

sub ui {
    my $this = shift;
    my $result = '';
    my $badLSC = 0;

    $this->{LocalSiteDotCfg} = TWiki::findFileOnPath('LocalSite.cfg');
    unless ($this->{LocalSiteDotCfg}) {
        $this->{LocalSiteDotCfg} = TWiki::findFileOnPath('TWiki.spec') || '';
        $this->{LocalSiteDotCfg} =~ s/TWiki\.spec/LocalSite.cfg/;
    }

    # Get default settings by reading .spec files
    TWiki::Configure::Load::readDefaults();

    $TWiki::defaultCfg = _copy( \%TWiki::cfg );

    if (!$this->{LocalSiteDotCfg} ) {
        $this->{errors}++;
        $result .= $this->ERROR(<<HERE);
Could not find where LocalSite.cfg is supposed to go.
Use your LocalLib.cfg to set \$twikiLibPath to the 'lib' directory
for your install.
Please correct this error before continuing.
HERE
    } elsif( -e $this->{LocalSiteDotCfg} ) {
        eval {
            TWiki::Configure::Load::readConfig();
        };
        if ($@) {
            $result .= $this->WARN(<<HERE);
Existing configuration file has a configuration problem
that is causing a Perl error - the following message(s) was generated:
<pre>$@</pre>
You can continue, but configure will not pick up any of the existing
settings from this file unless you correct the perl error.
HERE
            $badLSC = 1;
        } elsif (!-w $this->{LocalSiteDotCfg} ) {
            $result .= $this->WARN(<<HERE);
Cannot write to existing configuration file<br />
$this->{LocalSiteDotCfg} is not writable.
You can view the configuration, but you will not be able to save.
Check the file permissions.
HERE
        }

    } else {
        # Doesn't exist (yet)
        my $errs = $this->checkCanCreateFile(
            $this->{LocalSiteDotCfg});

        if ($errs) {
            $result .= $this->WARN(<<HERE);
Configuration file $this->{LocalSiteDotCfg} does not exist, and I cannot
write a new configuration file due to these errors:
<pre/>$errs<pre>
You can view the default configuration, but you will not be able to save.
HERE
            $badLSC = 1;
        } else {
            $result .= $this->WARN(<<HERE);
Could not find existing configuration file $this->{LocalSiteDotCfg}.<br />
This may be because this is the first time you have run configure. In this
case you can simply ignore this warning until you have filled in your
<a rel="nofollow" href="#" onclick="foldBlock('GeneralPathSettings'); return false;">
General path settings</a>.
HERE
            $badLSC = 1;
        }
    }

    # If we got this far without definitions for key variables, then
    # we need to default them. otherwise we get peppered with
    # 'uninitialised variable' alerts later.
    foreach my $var qw( DataDir DefaultUrlHost PubUrlPath
                        PubDir TemplateDir ScriptUrlPath LocalesDir ) {
        # NOT SET tells the checker to try and guess the value later on
        $TWiki::cfg{$var} ||= 'NOT SET';
    }

    # Make %ENV safer for CGI (should reflect TWiki.pm)
    $TWiki::cfg{DETECTED}{originalPath} = $ENV{PATH} || '';
    if( $TWiki::cfg{SafeEnvPath} ) {
        # SMELL: this untaint probably isn't needed
        my $ut = $TWiki::cfg{SafeEnvPath};
        $ut =~ /^(.*)$/;
        $ENV{PATH} = $1;
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    return $result;
}

sub _copy {
    my $n = shift;

    return undef unless defined( $n );

    if (UNIVERSAL::isa($n, 'ARRAY')) {
        my @new;
        for ( 0..$#$n ) {
            push(@new, _copy( $n->[$_] ));
        }
        return \@new;
    }
    elsif (UNIVERSAL::isa($n, 'HASH')) {
        my %new;
        for ( keys %$n ) {
            $new{$_} = _copy( $n->{$_} );
        }
        return \%new;
    }
    elsif (UNIVERSAL::isa($n, 'Regexp')) {
        return qr/$n/;
    }
    elsif (UNIVERSAL::isa($n, 'REF') || UNIVERSAL::isa($n, 'SCALAR')) {
        $n = _copy($$n);
        return \$n;
    }
    else {
        return $n;
    }
}

1;
