# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Derived from Contrib::Attrs, which is
# Copyright (C) 2001 Motorola - All rights reserved
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

---+ package TWiki::Attrs

Class of attribute sets, designed for parsing and storing attribute values
from a TWiki tag e.g. =%TAG{fred='bad' "sad" joe="mad"}%=

An attribute set is a map containing an entry for each parameter. The
default parameter (unnamed quoted string) is named <code>_<nop>DEFAULT</code> in the map.

Attributes declared later in the string will override those of the same
name defined earlier. The one exception to this is the _DEFAULT key, where
the _first_ instance of a setting is always taken.

As well as standard TWiki syntax (parameter values double-quoted)
it also parses single-quoted values, unquoted spaceless
values, spaces around the =, and commas as well as spaces separating values,
though none of these alternatives is advertised in documentation and
the extended syntax can be turned off by passing the 'strict' parameter
to =new=.

This class replaces the old TWiki::extractNameValuePair and
TWiki::extractParameters.

=cut

package TWiki::Attrs;

use strict;
use Assert;

use vars qw( $ERRORKEY $DEFAULTKEY $RAWKEY );

$ERRORKEY   = '_ERROR';
$DEFAULTKEY = '_DEFAULT';
$RAWKEY     = '_RAW';

=pod

---++ ClassMethod new ($string, $friendly) => \%attrsObjectRef

   * =$string= - String containing attribute specification
   * =$friendly= - if true, the parse will be according to the extended syntax pioneered by the original Contrib::Attrs. Otherwise it will be strict as per traditional TWiki syntax.

Parse a standard attribute string containing name=value pairs and create a new
attributes object. The value may be a word or a quoted string. If there is an
error during parsing, the parse will complete but $attrs->{_ERROR} will be
set in the new object. $attrs->{_RAW} will always contain the full unprocessed
$string.

Extended syntax example:
<verbatim>
my $attrs = new TWiki::Attrs('the="time \\"has come", "the walrus" said to=speak of=\'many \\'things\', 1);
</verbatim>
In this example:
   * =the= will be =time "has come=
   * <code>_<nop>_<nop>default__</code> will be =the walrus=
   * =said= will be =on=
   * =to= will be =speak=
   * =of= will be =many 'things=

Only " and ' are escaped.

Traditional syntax is as old TWiki, except that the whole string is parsed
(the old parser would only recognise default values in position 1, nowhere
else)

=cut

sub new {
    my ( $class, $string, $friendly ) = @_;
    my $this = bless( {}, $class );

    $this->{$RAWKEY} = $string;

    return $this unless defined( $string );

    $string =~ s/\\(["'])/$TWiki::TranslationToken.sprintf("%.2u", ord($1))/ge;  # escapes

    my $sep = ( $friendly ? "[\\s,]" : "\\s" );
    my $first = 1;

    if( !$friendly && $string =~ s/^\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/$2/s ) {
        $this->{$DEFAULTKEY} = $1;
    }
    while ( $string =~ m/\S/s ) {
        # name="value" pairs
        if ( $string =~ s/^$sep*(\w+)\s*=\s*\"(.*?)\"//is ) {
            $this->{$1} = $2;
            $first = 0;
        }
        # simple double-quoted value with no name, sets the default
        elsif ( $string =~ s/^$sep*\"(.*?)\"//os ) {
            $this->{$DEFAULTKEY} = $1
              unless defined( $this->{$DEFAULTKEY} );
            $first = 0;
        }
        elsif ( $friendly ) {
            # name='value' pairs
            if ( $string =~ s/^$sep*(\w+)\s*=\s*'(.*?)'//is ) {
                $this->{$1} = $2;
            }
            # name=value pairs
            elsif ( $string =~ s/^$sep*(\w+)\s*=\s*([^\s,\}\'\"]*)//is ) {
                $this->{$1} = $2;
            }
            # simple single-quoted value with no name, sets the default
            elsif ( $string =~ s/^$sep*'(.*?)'//os ) {
                $this->{$DEFAULTKEY} = $1
                  unless defined( $this->{$DEFAULTKEY} );
            }
            # simple name with no value (boolean, or _DEFAULT)
            elsif ( $string =~ s/^$sep*([a-z]\w*)\b//is ) {
                my $key = $1;
                $this->{$key} = 1;
            }
            # otherwise the whole string - sans padding - is the default
            else {
                if( $string =~ m/^\s*(.*?)\s*$/s &&
                      !defined($this->{$DEFAULTKEY})) {
                    $this->{$DEFAULTKEY} = $1;
                }
                last;
            }
        } elsif( $string =~ m/^\s*(.*?)\s*$/s ) {
            $this->{$DEFAULTKEY} = $1 if( $first );
            last;
        }
    }
    foreach my $k ( keys %$this ) {
        $this->{$k} =~ s/$TWiki::TranslationToken(\d\d)/chr($1)/geo;  # escapes
    }
    return $this;
}

=pod

---++ ObjectMethod isEmpty() -> boolean

Return false if attribute set is not empty.

=cut

sub isEmpty {
  my $this = shift;

  ASSERT( $this->isa( 'TWiki::Attrs' )) if DEBUG;

  foreach my $k ( keys %$this ) {
      return 0 if $k ne $RAWKEY;
  }
  return 1;
}

=pod

---++ ObjectMethod remove($key) -> $value

| $key | Attribute to remove |
Remove an attr value from the map, return old value. After a call to
=remove= the attribute is no longer defined.

=cut

sub remove {
  my ( $this, $attr ) = @_;
  ASSERT($this->isa( 'TWiki::Attrs' )) if DEBUG;
  my $val = $this->{$attr};
  delete( $this->{$attr} ) if ( exists $this->{$attr} );
  return $val;
}

=pod

---++ ObjectMethod stringify() -> $string

Generate a printed form for the map, using standard
attribute syntax, with only the single-quote extension
syntax observed (no {} brackets, though).

=cut

sub stringify {
  my $this = shift;
  ASSERT($this->isa( 'TWiki::Attrs')) if DEBUG;
  my $key;
  my @ss;
  foreach $key ( sort keys %$this ) {
	if ( $key ne $ERRORKEY && $key ne $RAWKEY ) {
	  my $es = ( $key eq $DEFAULTKEY ) ? '' : $key.'=';
	  my $val = $this->{$key};
      $val =~ s/"/\\"/g;
      push( @ss, $es.'"'.$val.'"' );
	}
  }
  return join( ' ', @ss );
}


=pod

---++ StaticMethod extractValue() -> $string

Legacy support, formerly known as extractNameValuePair. This
static method uses context information to determine how a value
string is to be parsed. For example, if you have an attribute string
like this:

"abc def="ghi" jkl" def="qqq"

then call extractValue( "def" ), it will return "ghi".

=cut

sub extractValue {
    my( $str, $name ) = @_;

    my $value = '';
    return $value unless( $str );
    $str =~ s/\\\"/\\$TWiki::TranslationToken/g;  # escape \"

    if( $name ) {
        # format is: %VAR{ ... name = "value" }%
        if( $str =~ /(^|[^\S])$name\s*=\s*\"([^\"]*)\"/ ) {
            $value = $2 if defined $2;  # distinguish between '' and "0"
        }

    } else {
        # test if format: { "value" ... }
        if( $str =~ /(^|\=\s*\"[^\"]*\")\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/ ) {
            # is: %VAR{ "value" }%
            # or: %VAR{ "value" param="etc" ... }%
            # or: %VAR{ ... = "..." "value" ... }%
            # Note: "value" may contain embedded double quotes
            $value = $2 if defined $2;  # distinguish between '' and "0";

        } elsif( ( $str =~ /^\s*\w+\s*=\s*\"([^\"]*)/ ) && ( $1 ) ) {
            # is: %VAR{ name = "value" }%
            # do nothing, is not a standalone var

        } else {
            # format is: %VAR{ value }%
            $value = $str;
        }
    }
    $value =~ s/\\$TWiki::TranslationToken/\"/go;  # resolve \"
    return $value;
}

=pod

---++ ObjectMethod get($key) -> $value

| $key | Attribute to get |
Get an attr value from the map.

Synonymous with $attrs->{$key}. Retained mainly for compatibility with
the old AttrsContrib.

=cut

sub get {
    my( $this, $field) = @_;
    return $this->{$field};
}

1;
