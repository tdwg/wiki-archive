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
package TWiki::Configure::UIs::MAIN;

use strict;

use base 'TWiki::Configure::UI';

use TWiki::Configure::Type;

sub new {
    my $class = shift;
    my $this = bless($class->SUPER::new(), $class);

    @{$this->{blocks}} = ();
    @{$this->{heads}} = ();
    $this->{depth} = 0;
    $this->{output} = '';

    return $this;
}

sub parse {
    my ($this, $file) = @_;

    my $cfgfile = TWiki::findFileOnPath($file);
    return unless $cfgfile;
    open(F, $cfgfile) || return '';
    undef $/;
    my $text = <F>;
    close(F);

    my $type = '';
    my $descr;
    my $opts;
    my $output = '';
    foreach (split(/\r?\n/, $text)) {

        if( m/^# \*\*([A-Z]+)(\s*.*?)\*\*/ ) {

            if( $type eq '_HELP' ) {
                $this->{blocks}->[$this->{depth}] .=
                  TWiki::Configure::UI::docBlock( $descr );
            }
            $type = $1;
            $opts = $2 || '';
            $opts .= ' '; # to simplify parsing
            $descr = '';

        } elsif ($type && /\$(TWiki::)?cfg(.*?)\s*=/) {

            if( $type eq '_HELP' ) {
                $this->{blocks}->[$this->{depth}] .=
                  TWiki::Configure::UI::docBlock( $descr );
            } else {
                my $value = new TWiki::Configure::Value(
                    $type, $opts, $descr, $2);
                $this->{blocks}->[$this->{depth}] .= $value->buildInputFields();
            }
            $type = '';
            $descr = '';

        } elsif( m/^#---(\++) *(.*?)$/ ) {

            my $ndepth = length($1);
            my $nhead = $2;
            while( $this->{depth} >= $ndepth ) {
                if ($this->{depth} <= 1) {
                    $output .= TWiki::Configure::UI::foldableBlock(
                        $this->{heads}->[$this->{depth}], '',
                        $this->{blocks}->[$this->{depth}]);
                } else {
                    $this->{blocks}->[$this->{depth} - 1] .=
                      TWiki::Configure::UI::ordinaryBlock(
                          $this->{depth}, $this->{heads}->[$this->{depth}], '',
                          $this->{blocks}->[$this->{depth}]);
                }
                $this->{depth}--;
            }
            $this->{depth} = $ndepth;
            $this->{heads}->[$this->{depth}] = $nhead;
            $this->{blocks}->[$this->{depth}] = '';
            $type = '_HELP';

        } elsif( m/^# \*([A-Z]+)\*/ ) {

            my $ui = $1;
            if( $type eq '_HELP' ) {
                $this->{blocks}->[$this->{depth}] .=
                  TWiki::Configure::UI::docBlock( $descr );
                $descr = '';
            }
            $ui = TWiki::Configure::UI::load($ui);
            $this->{blocks}->[$this->{depth}] .= $ui->ui();

        } elsif( $type ) {
            $descr .= "$_ ";
        }
    }
    $this->{output} .= $output;
}

sub ui {
    my $this = shift;

    print $this->{output};

    while( $this->{depth} && $this->{blocks}->[$this->{depth}]) {
        if ($this->{depth} <= 1) {
            print TWiki::Configure::UI::foldableBlock(
                $this->{heads}->[$this->{depth}], '',
                $this->{blocks}->[$this->{depth}]);
        } else {
            $this->{blocks}->[ $this->{depth} - 1] .=
              TWiki::Configure::UI::ordinaryBlock(
                  $this->{depth}, $this->{heads}->[$this->{depth}],
                  '', $this->{blocks}->[$this->{depth}]);
        }
        $this->{depth}--;
    }
}

1;
