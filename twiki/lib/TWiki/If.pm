# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors
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

use strict;
use Assert;

=pod

---+ package TWiki::If

Support for the conditions in %IF{} statements. Basically a simple
stack-based parser for infix expressions that generates a parse
tree that can subsequently be evaluated.

=cut

package TWiki::IfNode;

=pod

---++ ClassMethod new( $l, $o, $r ) -> \$if

Construct a new parse node,

=cut

sub new {
    my( $class, $left, $op, $right ) = @_;
    my $this = bless( {}, $class );
    $this->{right} = $right;
    $this->{left} = $left;
    $this->{op} = $op;
    return $this;
}

=pod

---++ ObjectMethod evaluate($twiki) -> $result

Execute the parse node.

=cut

sub evaluate {
    my( $this, $session ) = @_;

    return $this->{op} unless ref( $this->{op} );

    my $fn = $this->{op}->{exec};
    return &$fn( $session, $this->{left}, $this->{right} );
}

sub stringify {
    my $this = shift;

    return $this->{op} unless ref( $this->{op} );

    my $res = $this->{op}->{name};
    if( $this->{left} ) {
        $res = $this->{left}->stringify() . $res;
    }
    return '('.$res . $this->{right}->stringify().')';
}

package TWiki::If;

# Operator precedences
my %defOps;

$defOps{context} =
  { name => 'context',
    prec => 5,
    type => 0, # unary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        return $twiki->inContext($b->evaluate($twiki)) || 0;
    }
   };
$defOps{config} =
  { name => 'config',
    prec => 5,
    type => 0, # unary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $x;
        eval '$x = $TWiki::cfg'.$b;
        return $x;
    }
   };
$defOps{'$'} =
  { name => '$',
    prec => 5,
    type => 0, # unary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $text = $b->evaluate($twiki) || '';
        if( $text && defined( $twiki->{cgiQuery}->param( $text ))) {
            return $twiki->{cgiQuery}->param( $text );
        }
        $text = "%$text%";
        $twiki->_expandAllTags(\$text,
                               $twiki->{topicName},
                               $twiki->{webName});
        return $text || '';
    }
   };
$defOps{defined} =
  { name => 'defined',
    prec => 5,
    type => 0, # unary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $eval =  $b->evaluate($twiki);
        return 0 unless $eval;
        return 1 if( defined( $twiki->{cgiQuery}->param( $eval )));
        return 1 if( defined( $twiki->{prefs}->getPreferencesValue( $eval )));
        return 1 if( defined( $twiki->{SESSION_TAGS}{$eval} ));
        return 0;
    }
   };
$defOps{'='} =
  { name => '=',
    prec => 4,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $ea = $a->evaluate($twiki) || '';
        my $eb = $b->evaluate($twiki) || '';
        return $ea eq $eb;
    }
   };
$defOps{'!='} =
  { name => '!=',
    prec => 4,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $ea = $a->evaluate($twiki) || '';
        my $eb = $b->evaluate($twiki) || '';
        return $ea ne $eb;
    }
   };
$defOps{'>='} =
  { name => '>=',
    prec => 4,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $ea = $a->evaluate($twiki) || 0;
        my $eb = $b->evaluate($twiki) || 0;
        return $ea >= $eb;
    }
   };
$defOps{'<='} =
  { name => '<=',
    prec => 4,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $ea = $a->evaluate($twiki) || 0;
        my $eb = $b->evaluate($twiki) || 0;
        return $ea <= $eb;
    }
   };
$defOps{'>'} =
  { name => '>',
    prec => 4,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $ea = $a->evaluate($twiki) || 0;
        my $eb = $b->evaluate($twiki) || 0;
        return $ea > $eb;
    }
   };
$defOps{'<'} =
  { name => '<',
    prec => 4,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        my $ea = $a->evaluate($twiki) || 0;
        my $eb = $b->evaluate($twiki) || 0;
        return $ea < $eb;
    }
   };
$defOps{not} =
  { name => 'not',
    prec => 3,
    type => 0, # unary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        return !$b->evaluate($twiki);
    }
   };
$defOps{and} =
  { name => 'and',
    prec => 2,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        return 0 unless $a->evaluate($twiki);
        return $b->evaluate($twiki);
    }
   };
$defOps{or} =
  { name => 'or',
    prec => 1,
    type => 1, # binary
    exec => sub {
        my( $twiki, $a, $b ) = @_;
        return 1 if $a->evaluate($twiki);
        return $b->evaluate($twiki);
    }
   };

=pod

---++ ClassMethod new( \%operators ) -> \%factory

Construct a new if node factory.

   * =\%operators= reference to a hash of operators.

Each operator must have the following fields: prec (precedence) type (0 unary 1 binary) exec (ref to a function to execute). If not provided, the default set of boolean operations supported by %IF is used.

=cut

sub new {
    my( $class, $operators ) = @_;
    my $this = bless( {}, $class );

    $this->{operators} = $operators || \%defOps;

    # build up REs that match all the types
    foreach my $opn ( keys %{$this->{operators}} ) {
        my $re = $opn;
        $re =~ s/(\W)/\\$1/g;
        $re .= '\b' if $re =~ /\w$/;
        $this->{RE}[$this->{operators}->{$opn}->{type}] .= $re.'|';
    }
    $this->{RE}[0] =~ s/\|$//;
    $this->{RE}[1] =~ s/\|$//;

    return $this;
}

=pod

---++ ObjectMethod parse( $string ) -> \$if

   * =$string= - string containing an expression to parse

Construct a new search node by parsing the passed expression. Return
the new object.

=cut

sub parse {
    my( $this, $string ) = @_;
    if ( defined( $string )) {
        if ( $string =~ m/^\s*$/o ) {
            return new TWiki::IfNode( undef, '', undef );
        } else {
            my( $node, $rest ) = $this->_parse( $string );
            return $node;
        }
    }
    return undef;
}

# PRIVATE STATIC simple stack parser for grabbing boolean expressions
sub _parse {
    my( $this, $string ) = @_;
    $string .= " ";
    my @opands;
    my @opers;
    while( $string =~ m/\S/o ) {
        if ( $string =~ s/^\s*($this->{RE}[0])//i ||
               $string =~ s/^\s*($this->{RE}[1])//i ) {

            my $op = $this->{operators}->{lc($1)};
            while( scalar( @opers ) > 0 &&
                     $op->{prec} < $opers[$#opers]->{prec} ) {
                $this->_apply( \@opers, \@opands );
            }
            die($this->{RE}[1]) unless $op;
            push( @opers, $op );
        }
        elsif( $string =~ s/^\s*'(.*?)'//o ) {
            push( @opands, new TWiki::IfNode( undef, $1, undef ));
        }
        elsif( $string =~ s/^\s*(\w+)//o ) {
            push( @opands, new TWiki::IfNode( undef, $1, undef ));
        }
        elsif( $string =~ s/^\s*(({\w+})+)//o ) {
            # {config expression}
            push( @opands, new TWiki::IfNode(
                undef, $this->{operators}->{config}, $1 ));
        }
        elsif( $string =~ s/\s*\(//o ) {
            my $oa;
            ( $oa, $string ) = $this->_parse( $string );
            push( @opands, $oa );
        }
        elsif( $string =~ s/^\s*\)//o ) {
            last;
        }
        else{
            # the parser is stuck; we have done as well as we can, so return
            $this->{error} = 'Bad expression at '.$string;
            return undef;
        }
    }
    while( scalar( @opers ) > 0 ) {
        return undef unless $this->_apply( \@opers, \@opands );
    }
    unless( scalar( @opands ) == 1 ) {
        $this->{error} = 'Missing operator?';
    }
    return ( pop( @opands ), $string );
}

# PRIVATE STATIC generate a Search by popping the top two operands
# and the top operator. Push the result back onto the operand stack.
sub _apply {
    my ( $this, $opers, $opands ) = @_;
    my $o = pop( @$opers );
    my $r = pop( @$opands );
    unless( defined( $r )) {
        $this->{error} = 'Missing operand after '.$o->{name};
        return undef;
    }
    my $l = undef;
    if( $o->{type} == 1 ) {
        # binary
        $l = pop( @$opands );
        unless( defined( $l )) {
            $this->{error} = 'Missing operand before '.$o->{name};
            return undef;
        }
    }
    my $n = new TWiki::IfNode( $l, $o, $r );
    push( @$opands, $n);
    return $n;
}

1;
