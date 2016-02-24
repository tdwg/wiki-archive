# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
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

=pod twiki

---+ package TWiki::OopsException

Exception used to raise a request to redirect to an Oops URL.
An OopsException thrown anywhere in the code will redirect the
browser to a url based on the =oops= script. =oops= requires a
=template= parameter, that is the name of a template file from
the =templates= directory. This file will be expanded and the
parameter values passed to the exception instantiated. The
result will be shown in the browser.

=cut

package TWiki::OopsException;

use strict;
use Error;
use Assert;

@TWiki::OopsException::ISA = qw(Error);

=pod

---++ ClassMethod new( $template, ...)
   * =template= is the name of an oops template
The remaining parameters are interpreted as key-value pairs. The following keys are used:
   * =web= will be used as the web for the oops
   * =topic= will be used as the topic for the oops
   * =def= - is the (optional) name of a TMPL:DEF within the template
   * =keep= - if set, the exception handler should try it's damndest to retain parameter values from the query.
   * =params= is a reference to an array of parameters. These will be substituted for !%PARAM1%, !%PARAM2% ... !%PARAMn% in the template.

=cut

sub new {
    my( $class, $template ) = @_;
    my $this = bless( $class->SUPER::new(), $class );
    $this->{template} = $template;
    ASSERT( scalar( @_ ) % 2 == 0 ) if DEBUG;
    while ( my $key = shift @_ ) {
        my $val = shift @_;
        $this->{$key} = $val;
    }
    return $this;
}

=pod

---++ ObjectMethod stringify( [$session] ) -> $string

Generates a string representation for the object. if a session is passed in, and
the excpetion specifies a def, then that def is expanded. This is to allow
internal expansion of oops exceptions for example when performing bulk operations.

=cut

sub stringify {
    my( $this, $session ) = @_;

    if ($this->{template} && $this->{def} && $session) {
        # load the defs
        $session->{templates}->readTemplate( 'oops'.$this->{template},
                                             $session->getSkin() );
        my $message = $session->{templates}->expandTemplate( $this->{def} );
        $message = $session->handleCommonTags( $message, $this->{web}, $this->{topic} );
        my $n = 1;
        foreach my $param ( @{$this->{params}} ) {
            $message =~ s/%PARAM$n%/$param/g;
            $n++;
        }
        return $message;
    } else {
        my $s = 'OopsException(';
        $s .= $this->{template};
        $s .= '/'.$this->{def} if $this->{def};
        $s .= ' web=>'.$this->{web} if $this->{web};
        $s .= ' topic=>'.$this->{topic} if $this->{topic};
        $s .= ' keep=>1' if $this->{keep};
        if( defined $this->{params} ) {
            if( ref($this->{params}) eq 'ARRAY' ) {
                $s .= ' params=>['.join( ",", @{$this->{params}} ).']';
            } else {
                $s .= ' params=>'.$this->{params};
            }
        }
        return $s.')';
    }
}

1;
