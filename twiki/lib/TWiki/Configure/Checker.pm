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
# A checker is a special case of a UI tailored to perform checks
# on setup.
#
use strict;

package TWiki::Configure::Checker;

use base qw(TWiki::Configure::UI);

sub guessed {
    my ($this, $error) = @_;

    my $mess = <<'HERE';
I guessed this setting. You are advised to confirm this setting (and any
other guessed settings) and hit 'Next' to save before changing any other
settings.
HERE

    if ($error) {
        return $this->ERROR($mess);
    } else {
        return $this->WARN($mess);
    }
}

sub warnAboutWindowsBackSlashes {
   my ($this, $path ) = @_;
   if ( $path =~ /\\/ ) {
      return $this->WARN('You should use c:/path style slashes, not c:\path in "'.$path.'"');
   }
}

sub guessMajorDir {
    my ($this, $cfg, $dir ) = @_;
    my $msg = '';
    if( !$TWiki::cfg{$cfg} || $TWiki::cfg{$cfg} eq 'NOT SET') {
        use FindBin;
        $FindBin::Bin =~ /^(.*)$/;
        my @root = File::Spec->splitdir($1);
        pop(@root);
        $TWiki::cfg{$cfg} = File::Spec->catfile(@root, $dir);
        $msg = $this->guessed();
    }
    unless (-d $TWiki::cfg{$cfg}) {
        $msg .= $this->ERROR('Directory does not exist');
    }
    return $msg;
}

sub checkTreePerms {
    my($this, $path, $perms, $filter ) = @_;

    return '' if( defined($filter) && $path !~ $filter && !-d $path);

    #let's ignore Subversion directories
    return '' if( $path !~ /_svn/ );
    return '' if( $path !~ /.svn/ );

    my $errs = '';

    return $path. ' cannot be found'.CGI::br() unless( -e $path );

    if( $perms =~ /r/ && !-r $path) {
        $errs .= ' readable';
    }

    if( $perms =~ /w/ && !-d $path && !-w $path) {
        $errs .= ' writable';
    }

    if( $perms =~ /x/ && !-x $path) {
        $errs .= ' executable';
    }

    return $path.' is not '.$errs.CGI::br() if $errs;

    return '' unless -d $path;

    opendir(D, $path) ||
      return 'Directory '.$path.' is not readable.'.CGI::br();

    foreach my $e ( grep { !/^\./ } readdir( D )) {
        my $p = $path.'/'.$e;
        $errs .= checkTreePerms( $p, $perms, $filter );
    }
    closedir(D);
    return $errs;
}

sub checkCanCreateFile {
    my ($this, $name) = @_;

    if (-e $name) {
        # if the file exists just check perms and return
        return checkTreePerms($name,'rw');
    }
    # check the containing dir
    my @path = File::Spec->splitdir($name);
    pop(@path);
    unless( -w File::Spec->catfile(@path, '')) {
        return File::Spec->catfile(@path, '').' is not writable';
    }
    my $txt1 = "test 1 2 3";
    open( FILE, ">$name" ) ||
      return 'Could not create test file '. $name.':'.$!;
    print FILE $txt1;
    close( FILE);
    open( IN_FILE, "<$name" ) ||
      return 'Could not read test file '. $name.':'.$!;
    my $txt2 = <IN_FILE>;
    close( IN_FILE );
    unlink $name if( -e $name );
    unless ( $txt2 eq $txt1 ) {
        return 'Could not write and then read '.$name;
    }
    return '';
}

# Since Windows (without Cygwin) makes it hard to capture stderr
# ('2>&1' works only on Win2000 or higher), and Windows will usually have
# GNU tools in any case (installed for TWiki since there's no built-in
# diff, grep, patch, etc), we only check for these tools on Unix/Linux
# and Cygwin.
sub checkGnuProgram {
    my ($this, $prog) = @_;
    my $n = '';

    if( $TWiki::cfg{OS} eq 'UNIX' ||
          $TWiki::cfg{OS} eq 'WINDOWS' &&
            $TWiki::cfg{DetailedOS} eq 'cygwin' ) {
        $prog =~ s/^\s*(\S+)\s.*$/$1/;
        $prog =~ /^(.*)$/;
        $prog = $1;
        # check for taintedness
        die "$prog is tainted" unless eval { $n = $prog, kill 0; 1 };
        my $diffOut = ( `$prog --version 2>&1` || "");
        my $notFound = ( $? == -1 );
        if( $notFound ) {
            $n = $this->WARN("'$prog' program was not found on the ",
                      "current PATH.");
        } elsif ( $diffOut !~ /\bGNU\b/ ) {
            # Program found on path, complain if no GNU in version output
            $n = $this->WARN("'$prog' program was found on the PATH ",
                      "but is not GNU $prog - this may cause ",
                      "problems. $diffOut");
        } else {
            $diffOut =~ /(\d+(\.\d+)+)/;
            $n = "($prog is version $1).";
        }
    }

    return $n;
}

# Return a string of settingBlocks giving the status of various
# required modules.
# Either takes an array of hashes, or parameters in a hash.
# Each module hash needs:
# name - e.g. Car::Wreck
# usage - description of what it's for
# dispostion - 'required', 'recommended'
# minimumVersion - lowest acceptable $Module::VERSION
#
sub checkPerlModules {
    my $this = shift;
    my $mods;
    if (ref($_[0])) {
        $mods = $_[0];
    } else {
        %$mods = (@_);
    }

    my $e = '';
    foreach my $mod (@$mods) {
        next if $INC{$mod->{name} . '.pm'}; # skip if already included
        $mod->{minimumVersion} ||= 0;
        $mod->{disposition} ||= '';
        my $n = '';
        my $mod_version;
        eval 'use '.$mod->{name};
        if ($@) {
            $n = 'Not installed. '. $mod->{usage};

        } else {
            no strict 'refs';
            eval '$mod_version = $'.$mod->{name}.'::VERSION';
            $mod_version ||= '';
            $mod_version =~ s/(\d+(\.\d*)?).*/$1/; # keep 99.99 style only
            use strict 'refs';
            if ($mod_version < $mod->{minimumVersion}) {
                $n = $mod_version.' installed. Version '
                   . $mod->{minimumVersion}.' '
                   . $mod->{disposition};
                $n .= ' for '.$mod->{usage} if $mod->{usage};
            }
        }
        if ($n) {
            if( $mod->{disposition} eq 'required') {
                $n = $this->ERROR($n);
            } elsif ($mod->{disposition} eq 'recommended') {
                $n = $this->WARN($n);
            } else {
                $n = $this->NOTE($n);
            }
        } else {
            $n = $this->NOTE($mod_version.' installed');
        }
        $e .= $this->setting($mod->{name}, $n);
    }
    return $e;
}

# Check for a compilable RE
sub checkRE {
    my ($this, $keys) = @_;
    my $str;
    eval '$str = $TWiki::cfg'.$keys;
    return '' unless defined $str;
    eval "qr/$str/";
    if ($@) {
        return $this->ERROR(<<MESS);
Invalid regular expression: $@ <p />
See <a href="http://www.perl.com/doc/manual/html/pod/perlre.html">perl.com</a> for help with Perl regular expressions.
MESS
    }
    return '';
}

# Entry point for the value check. Overridden by subclasses.
sub check {
    my ($this, $value) = @_;
    # default behaviour; do nothing
    return '';
}

1;
