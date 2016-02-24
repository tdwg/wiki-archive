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

=pod

---+ package TWiki::Form

Object representing a single form definition.

=cut

package TWiki::Form;

use strict;
use Assert;
use Error qw( :try );
use TWiki::OopsException;
use CGI qw( -any );

use vars qw( $reservedFieldNames );

BEGIN {
    # The following are reserved as URL parameters to scripts and may not be
    # used as field names in forms.
    $reservedFieldNames =
      {
          action => 1,
          breaklock => 1,
          contenttype => 1,
          cover => 1,
          dontnotify => 1,
          editaction => 1,
          forcenewrevision => 1,
          formtemplate => 1,
          onlynewtopic => 1,
          onlywikiname => 1,
          originalrev => 1,
          skin => 1,
          templatetopic => 1,
          text => 1,
          topic => 1,
          topicparent => 1,
          user => 1,
      };
};

=pod

---++ ClassMethod new ( $session, $web, $form, $def )

   * $web - default web to recover form from, if $form doesn't specify a web
   * =$form= - topic name to read form definition from
   * =$def= - optional. a reference to a list of field definitions. if present,
              these definitions will be used, rather than those in =$form=.

May throw TWiki::OopsException

=cut

sub new {
    my( $class, $session, $web, $form, $def ) = @_;
    my $this = bless( {}, $class );

    ( $web, $form ) =
      $session->normalizeWebTopicName( $web, $form );

    my $store = $session->{store};

    $this->{session} = $session;
    $this->{web} = $web;
    $this->{topic} = $form;

    unless ( $def ) {

      # Read topic that defines the form
      unless( $store->topicExists( $web, $form ) ) {
        return undef;
      }
      my( $meta, $text ) =
	$store->readTopic( $session->{user}, $web, $form, undef );

      $this->{fields} = $this->_parseFormDefinition( $text );

    } else {

      $this->{fields} = $def;

    }

    # Expand out values arrays in the definition
    # SMELL: this should be done lazily
    foreach my $fieldDef ( @{$this->{fields}} ) {
        my @posValues = ();

        if( $fieldDef->{type} =~ /^(checkbox|radio|select)/ ) {
            @posValues = split( /,/, $fieldDef->{value} );
            my $topic = $fieldDef->{definingTopic} || $fieldDef->{name};
            my( $fieldWeb, $fieldTopic ) =
              $session->normalizeWebTopicName($web, $topic);
            if (!scalar(@posValues)) {
                if ( $store->topicExists( $fieldWeb, $fieldTopic ) ) {
                    my( $meta, $text ) =
                      $store->readTopic( $session->{user},
                                         $fieldWeb, $fieldTopic, undef );
                    # Add processing of SEARCHES for Lists
                    $text = $this->{session}->handleCommonTags(
                        $text,$this->{web},$this->{topic});
                    @posValues = _getPossibleFieldValues( $text );
                    $fieldDef->{type} ||= 'select';  #FIXME keep?
                }
            }
            #FIXME duplicates code in _getPossibleFieldValues?
            @posValues = map { $_ =~ s/^\s*(.*)\s*$/$1/; $_; } @posValues;
            $fieldDef->{value} = \@posValues;
        }

        if( $fieldDef->{mandatory} ) {
            $this->{mandatoryFieldsPresent} = 1;
        }
    }

    return $this;
}

# Get definition from supplied topic text
# Returns array of arrays
#   1st - list fields
#   2nd - name, title, type, size, vals, tooltip, attributes
#   Possible attributes are "M" (mandatory field)
sub _parseFormDefinition {
    my( $this, $text ) = @_;

    my $store = $this->{session}->{store};
    my @fields = ();
    my $inBlock = 0;
    $text =~ s/\\\r?\n//go; # remove trailing '\' and join continuation lines

    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* | *Attributes:* |
    # Tooltip and attributes are optional
    foreach( split( /\r?\n/, $text ) ) {
        if( /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/ ) {
            $inBlock = 1;
            next;
        }
        # Only insist on first field being present FIXME - use oops page instead?
        if( $inBlock && s/^\s*\|//o ) {
            my( $title, $type, $size, $vals, $tooltip, $attributes ) = split( /\|/ );
            $title ||= '';
            $title =~ s/^\s*//go;
            $title =~ s/\s*$//go;

            $attributes ||= '';
            $attributes =~ s/\s*//go;
            $attributes = '' if( ! $attributes );

            $type ||= '';
            $type = lc $type;
            $type =~ s/^\s*//go;
            $type =~ s/\s*$//go;
            $type = 'text' if( ! $type );

            $size ||= '';
            $size = _cleanField( $size );
            unless( $size ) {
                if( $type eq 'text' ) {
                    $size = 20;
                } elsif( $type eq 'textarea' ) {
                    $size = '40x5';
                } else {
                    $size = 1;
                }
            }

            $vals ||= '';
            $vals = $this->{session}->handleCommonTags($vals,$this->{web},$this->{topic});
	    $vals =~ s/<\/?(nop|noautolink)\/?>//go;
            $vals =~ s/^\s*//go;
            $vals =~ s/\s*$//go;

            # SMELL: What is this??? This looks like a hack!
            if( $vals eq '$users' ) {
                $vals = $TWiki::cfg{UsersWebName} . '.' .
                  join( ", ${TWiki::cfg{UsersWebName}}.",
                        ( $store->getTopicNames( $TWiki::cfg{UsersWebName} ) ) );
            }

            $tooltip ||= '';
            $tooltip =~ s/^\s*//go;
            $tooltip =~ s/\s*$//go;

            my $definingTopic = "";
            if( $title =~ /\[\[(.+)\]\[(.+)\]\]/ )  { # use common defining
                $definingTopic = _cleanField( $1 );      # topics with different
                $title = $2;                          # field titles
            }

            my $name = _cleanField( $title );

            # Rename fields with reserved names
            if( $reservedFieldNames->{$name} ) {
                $name .= '_';
                $title .= '_';
            }

	    my $mandatory = new TWiki::Attrs( $attributes, 1 );
	    $mandatory = defined $mandatory->{'m'} || defined $mandatory->{'M'};

            push( @fields,
                  { name => $name,
                    title => $title,
                    type => $type,
                    size => $size,
                    value => $vals,
                    tooltip => $tooltip,
                    attributes => $attributes,
		    mandatory => $mandatory,
                    definingTopic => $definingTopic
                   } );
        } else {
            $inBlock = 0;
        }
    }

    return \@fields;
}

sub _searchVals {
    my ( $session, $arg ) = @_;
    $arg =~ s/%WEB%/$session->{webName}/go;
    return $session->_SEARCH(new TWiki::Attrs($arg), $session->{topicName}, $session->{webName});
}

# Chop out all except A-Za-z0-9_.
# I'm sure there must have been a good reason for this once.
sub _cleanField {
    my( $text ) = @_;
    $text = '' if( ! $text );
    # TODO: make this dependent on a 'character set includes non-alpha'
    # setting in TWiki.cfg - and do same in Render.pm re 8859 test.
    # I18N: don't get rid of non-ASCII characters
    # TW: this is applied to the key in the field; it is not obvious
    # why we need I18N in the key (albeit there could be collisions due
    # to the filtering... but all the current topics are keyed on _cleanField
    $text =~ s/<nop>//go;    # support <nop> character in title
    $text =~ s/[^A-Za-z0-9_\.]//go;
    return $text;
}


# Possible field values for select, checkbox, radio from supplied topic text
sub _getPossibleFieldValues {
    my( $text ) = @_;
    my @defn = ();
    my $inBlock = 0;
    foreach( split( /\r?\n/, $text ) ) {
        if( /^\s*\|\s*\*Name\*\s*\|/ ) {
            $inBlock = 1;
        } else {
            if( /^\s*\|\s*([^|]*)\s*\|/ ) {
                my $item = $1;
                $item =~ s/\s+$//go;
                $item =~ s/^\s+//go;
                if( $inBlock ) {
                    push @defn, $item;
                }
            } else {
                $inBlock = 0;
            }
        }
    }
    return @defn;
}

# Generate a link to the given topic, so we can bring up details in a
# separate window.
sub _link {
    my( $this, $string, $tooltip, $topic ) = @_;

    $string =~ s/[\[\]]//go;

    $topic ||= $string;
    $tooltip ||= $this->{session}->{i18n}->maketext('Click to see details in separate window');

    my $web;
    ( $web, $topic ) =
      $this->{session}->normalizeWebTopicName( $this->{web}, $topic );

    my $link;

    my $store = $this->{session}->{store};
    if( $store->topicExists( $web, $topic ) ) {
        $link =
          CGI::a(
              { target => $topic,
                onclick => 'return launchWindow("'.$web.'","'.$topic.'")',
                title => $tooltip,
                href =>$this->{session}->getScriptUrl( 0, 'view',
                                                       $web, $topic ),
                rel => 'nofollow'
               }, $string );
    } else {
        my $expanded = $this->{session}->handleCommonTags( $string, $web, $topic );
        if ( $tooltip ) {
            $link = CGI::span ( { title => $tooltip }, $expanded );
        } else {
            $link = $expanded;
        }
    }

    return $link;
}

=pod

---++ ObjectMethod renderForEdit( $web, $topic, $meta ) -> $html

   * =$web= the web of the topic being rendered
   * =$topic= the topic being rendered
   * =$meta= the meta data for the form

Render the form fields for entry during an edit session, using data values
from $meta

=cut

sub renderForEdit {
    my( $this, $web, $topic, $meta ) = @_;
    ASSERT($this->isa( 'TWiki::Form')) if DEBUG;
    ASSERT($meta->isa( 'TWiki::Meta')) if DEBUG;
    my $session = $this->{session};


    if( $this->{mandatoryFieldsPresent} ) {
        $session->enterContext( 'mandatoryfields' );
    }
    my $tmpl = $session->{templates}->readTemplate( "form" );
    $tmpl = $session->handleCommonTags( $tmpl, $web, $topic );

    # Note: if WEBFORMS preference is not set, can only delete form.
    $tmpl =~ s/%FORMTITLE%/$this->_link($this->{web}.'.'.$this->{topic})/geo;
    my( $text, $repeatTitledText, $repeatUntitledText, $afterText ) =
      split( /%REPEAT%/, $tmpl );

    foreach my $fieldDef ( @{$this->{fields}} ) {

        my $tooltip = $fieldDef->{tooltip};
        my $definingTopic = $fieldDef->{definingTopic};
        my $title = $fieldDef->{title};
        if (! $title && $fieldDef->{type} eq 'label') {
            # Special handling for untitled labels
            my $tmp = $repeatUntitledText;
            my $value =
              $session->{renderer}->getRenderedVersion(
                  $session->handleCommonTags($fieldDef->{value}, $web, $topic));
            $tmp =~ s/%ROWVALUE%/$value/go;
            $text .= $tmp;
        } else {
            my( $extra, $value );
            my $name = $fieldDef->{name};
            if( $name ) {
                my $field = $meta->get( 'FIELD', $name );
                $value = $field->{value};
            }
            if( !defined( $value ) &&
                  $fieldDef->{type} !~ /^checkbox/ ) {

                # Try and get a sensible default value from the form
                # definition. Doesn't make sense for checkboxes.
                $value = $fieldDef->{value};
                if( defined( $value )) {
                    $value = $session->handleCommonTags( $value, $web,
                                                         $topic );
                    $value = TWiki::expandStandardEscapes( $value ); # Item2837
                }
            }
            $value = '' unless defined $value;  # allow 0 values
            ( $extra, $value ) =
              $this->renderFieldForEdit( $fieldDef, $web, $topic, $value );

            my $tmp = $repeatTitledText;
            $tmp =~ s/%ROWTITLE%/$this->_link($title,$tooltip,$definingTopic)/geo;
            $tmp =~ s/%ROWEXTRA%/$extra/go;
            $tmp =~ s/%ROWVALUE%/$value/go;
            $text .= $tmp;
        }
    }

    $text .= $afterText;
    return $text;
}

=pod

---++ ObjectMethod renderFieldForEdit( $fieldDef, $web, $topic, $value) -> $html

   * =$fieldDef= the field being rendered
   * =$web= the web of the topic being rendered
   * =$topic= the topic being rendered
   * =$value= the current value of the field

Render a single form field for entry during an edit session, using data values
from $meta. Plugins can provide a handler that extends the set of supported
types

SMELL: this should be a method on a field class

=cut

sub renderFieldForEdit {
    my( $this, $fieldDef, $web, $topic, $value ) = @_;

    my $name = $fieldDef->{name};
    my $type = $fieldDef->{type} || '';
    my $size = $fieldDef->{size};
    my $attributes = $fieldDef->{attributes} || '';
    my $extra = '';
    my $session = $this->{session};

    if( $fieldDef->{mandatory} ) {
        $extra = CGI::span( { class => 'twikiAlert' }, ' *' );
    }

    my $options;
    my $item;
    my %attrs;
    my @defaults;

    $name = $this->cgiName( $name );

    # Give plugin field types a chance first
    my $output = $session->{plugins}->renderFormFieldForEditHandler
      ( $name, $type, $size, $value, $attributes, $fieldDef->{value} );

    if( $output ) {
        $value = $output;

    } elsif( $type eq 'date' ) {
      $size = 10 if( !$size || $size < 1 );
      $value = CGI::textfield({ name => $name,
				id => 'id'.$name,
				size=> $size,
				value => $value,
				class=> 'twikiInputField twikiEditFormDateField'});
      require TWiki::Contrib::JSCalendarContrib;
      unless ( $@ ) {
	my $ifFormat = $TWiki::cfg{JSCalendarContrib}{format} || '%e %b %Y';
	TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );
	$value .= '%TWISTY{link="" noscript="hide" start="show" prefix="&nbsp;"}%';
	$value .= CGI::image_button( -name => 'calendar',
				     -onclick =>
				     "return showCalendar('id$name','$ifFormat')",
				     -src=> $TWiki::cfg{PubUrlPath} . '/' .
				       $TWiki::cfg{SystemWebName} .
				       '/JSCalendarContrib/img.gif',
				     -alt => 'Calendar',
				     -class => 'twikiButton twikiEditFormCalendarButton' );
	$value .= '%ENDTWISTY%';
	$value = $session->{renderer}->getRenderedVersion( $session->handleCommonTags( $value, $web, $topic ) );
      }
    } elsif( $type eq 'text' ) {
        $value = CGI::textfield( -class => 'twikiInputField twikiEditFormTextField',
                                 -name => $name,
                                 -size => $size,
                                 -value => $value );

    } elsif( $type eq 'label' ) {
        # Interesting question: if something is defined as "label",
        # could it be changed by applications or is the value
        # necessarily identical to what is in the form? If we can
        # take it from the text, we must be sure it cannot be
        # changed through the URL?
        # Pth: Changed labels through the URL is a feature for TWiki applications
        my $renderedValue = $session->{renderer}->getRenderedVersion
          ( $session->handleCommonTags( $value, $web, $topic ));
        $value = CGI::hidden( -name => $name,
                              -value => $value );
        $value .= CGI::div( { class => 'twikiEditFormLabelField' },
                            $renderedValue );

    } elsif( $type eq 'textarea' ) {
        my $cols = 40;
        my $rows = 5;
        if( $size =~ /([0-9]+)x([0-9]+)/ ) {
            $cols = $1;
            $rows = $2;
        }
        $value = CGI::textarea( -class => 'twikiInputField twikiEditFormTextAreaField',
                                -cols => $cols,
                                -rows => $rows,
                                -name => $name,
                                -default => "\n".$value );

    } elsif( $type =~ /^select/ ) {
        $options = $fieldDef->{value};
        ASSERT( ref( $options )) if DEBUG;
        my $minSize = $size;
        my $maxSize = $size;
        if( $size =~ /([0-9]+)\.\.([0-9]+)/ ) {
            ( $minSize, $maxSize ) = ( $1, $2 );
        }
        my $isMulti  = ( $type =~ /\+multi/ );
        my $isValues = ( $type =~ /\+values/ );
        my $choices = '';
        foreach $item ( @$options ) {
	    $item = &TWiki::urlDecode($item);
            my $params = {
	      class=>'twikiEditFormOption'
	    };
            my $itemValue = $item;
            if( $isValues ) {
                if( $item =~ /^(.*?[^\\])=(.*)$/ ) {
                    $item = $1;
                    $itemValue = $2;
                    $params->{value} = $itemValue;
                }
                $item =~ s/\\=/=/g;
            }
            if( defined $itemValue && defined $value ) {
                my $selected;
                if( $isMulti ) {
                    $selected = ( $value =~ /^(.*,)?\s*$itemValue\s*(,.*)?$/ );
                } else {
                    $selected = ( $itemValue eq $value );
                }
                $params->{selected} = 'selected' if $selected;
            }
            $item =~ s/<nop/&lt\;nop/go;
            $choices .= CGI::option( $params, $item );
        }
        $size = scalar @$options;
        if( $size > $maxSize ) {
            $size = $maxSize;
        } elsif( $size < $minSize ) {
            $size = $minSize;
        }
        my $params = { 
	  class=>'twikiEditFormSelect',
	  name=>$name, 
	  size=>$size 
	};
        if( $isMulti ) {
            $params->{'multiple'}='on';
            $value  = CGI::Select( $params, $choices );
            # Item2410: We need a dummy control to detect the case where
            #           all checkboxes have been deliberately unchecked
	    # Item3061:
	    # Don't use CGI, it will insert the value from the query
	    # once again and we need an empt field here.
	    $value .= '<input type="hidden" name="'.$name.'" value="" />';
        }
        else {
            $value  = CGI::Select( $params, $choices );
        }

    } elsif( $type =~ /^checkbox/ ) {
        $options = $fieldDef->{value};
        ASSERT( ref( $options )) if DEBUG;
        if( $type eq 'checkbox+buttons' ) {
            my $boxes = scalar( @$options );
            $extra = CGI::br();
            $extra .= CGI::button
              ( -class => 'twikiCheckBox twikiEditFormCheckboxButton',
                -value => $session->{i18n}->maketext('Set all'),
                -onClick => 'checkAll(this,2,'.$boxes.',true)' );
            $extra .= '&nbsp;';
            $extra .= CGI::button
              ( -class => 'twikiCheckBox twikiEditFormCheckboxButton',
                -value => $session->{i18n}->maketext('Clear all'),
                -onClick => 'checkAll(this,1,'.$boxes.',false)');
        }
        my %isSelected = map { $_ => 1 } split(/\s*,\s*/, $value);
        foreach $item ( @$options ) {
            #NOTE: Does not expand $item in label
            $attrs{$item} =
              { class=>'twikiEditFormCheckboxField',
                label=>$session->handleCommonTags( $item,
                                                   $web,
                                                   $topic ) };

            if( $isSelected{$item} ) {
                $attrs{$item}{checked} = 'checked';
                push( @defaults, $item );
            }
        }
        $value = CGI::checkbox_group( -name => $name,
                                      -values => $options,
                                      -defaults => \@defaults,
                                      -columns => $size,
                                      -attributes => \%attrs );
        # Item2410: We need a dummy control to detect the case where
        #           all checkboxes have been deliberately unchecked
	# Item3061:
	# Don't use CGI, it will insert the value from the query
	# once again and we need an empt field here.
        $value .= '<input type="hidden" name="'.$name.'" value="" />';

    } elsif( $type eq 'radio' ) {
        $options = $fieldDef->{value};
        ASSERT( ref( $options )) if DEBUG;
        my $selected = '';
        foreach $item ( @$options ) {
            $attrs{$item} =
              { class=>'twikiRadioButton twikiEditFormRadioField',
                label=>$session->handleCommonTags( $item, $web, $topic ) };

            $selected = $item if( $item eq $value );
        }

        $value = CGI::radio_group( -name => $name,
                                   -values => $options,
                                   -default => $selected,
                                   -columns => $size,
                                   -attributes => \%attrs );

    } else {
        # Treat like text, make it reasonably long
        # SMELL: Sven thinks this should be an error condition - so users
        # know about typo's, and don't lose data when the typo is fixed
        $value = CGI::textfield( -class=>'twikiEditFormError',
                                 -name=>$name,
                                 -size=>80,
                                 -value=>$value );

    }
    return ( $extra, $value );
}

=pod

---++ ObjectMethod renderHidden( $meta ) -> $html

Render form fields found in the meta as hidden inputs, so they pass
through edits untouched.

=cut

sub renderHidden {
    my( $this, $meta ) = @_;
    ASSERT($this->isa( 'TWiki::Form')) if DEBUG;
    ASSERT($meta->isa( 'TWiki::Meta')) if DEBUG;
    my $session = $this->{session};

    my $text = "";

    foreach my $fieldDef ( @{$this->{fields}} ) {
        my $name = $fieldDef->{name};

        my $value;
        if( $name ) {
            my $field = $meta->get( 'FIELD', $name );
            $value = $field->{value};
        }

        if( !defined( $value ) &&
              $fieldDef->{type} !~ /^checkbox|\+multi/ ) {

            $value = $fieldDef->{value};
        }

        $value = '' unless defined $value;  # allow 0 values
        $text .= CGI::hidden( -name => $this->cgiName( $name ),
                              -value => $value );
    }

    return $text;
}

=pod

---++ ObjectMethod cgiName( $field ) -> $string

Generate the 'name' of the CGI parameter used to represent a field.

=cut

sub cgiName {
    my( $this, $fieldName ) = @_;

    # See Codev.FormFieldsNamedSameAsParameters
    return $fieldName;
}

=pod

---++ ObjectMethod getFieldValuesFromQuery($query, $metaObject) -> ( $seen, \@missing )

Extract new values for form fields from a query.

   * =$query= - the query
   * =$metaObject= - the meta object that is storing the form values

For each field, if there is a value in the query, use it.
Otherwise if there is already entry for the field in the meta, keep it.

Returns the number of fields which had values provided by the query, 
and a references to an array of the names of mandatory fields that were 
missing from the query.

=cut

sub getFieldValuesFromQuery {
    my( $this, $query, $meta ) = @_;
    ASSERT($this->isa( 'TWiki::Form')) if DEBUG;
    ASSERT($meta->isa( 'TWiki::Meta')) if DEBUG;
    my @missing;
    my $seen = 0;

    # Remove the old file defs so we apply the
    # order in the form definition, and not the
    # order in the previous meta object. See Item1982.
    my @old = $meta->find( 'FIELD' );
    $meta->remove('FIELD');

    foreach my $fieldDef ( @{$this->{fields}} ) {
        next unless $fieldDef->{name};

        my $param = $this->cgiName( $fieldDef->{name} );

        my $value = $query->param( $param );

        if (defined $value) {
            $seen++;
            if ($this->{session}->inContext('edit')) {
                $value  =  TWiki::expandStandardEscapes( $value );
            }
        }

        # checkbox and multi both allow multiple values
        if( $fieldDef->{type} =~ /^checkbox|\+multi/ ) {
            my @values = $query->param( $param );
	    if ($#values>=0) {
	      if ($#values==0) {
		@values = split /\,|%2C/, $values[0];
	      }
	      my %vset = ();
	      foreach my $val (@values) {
		$val =~ s/^\s*//o;
		$val =~ s/\s*$//o;
		$vset{$val} = (defined $val && $val =~ /\S/); # skip empty values
	      }
	      $value = '';
	      foreach my $flditem (@{$fieldDef->{value}}) {
		# Maintain order of definition
		if ($vset{$flditem}) {
		  $value .= ', ' if $value;
		  $value .= $flditem;
		}
	      }
	    }
        }

        my $preDef;
        foreach my $item ( @old ) {
            if( $item->{name} eq $fieldDef->{name} ) {
                $preDef = $item;
                last;
            }
        }

        if( $fieldDef->{mandatory} && !$value &&
              ( !$preDef || !$preDef->{value} ) ) {
            # Remember missing mandatory fields
            push( @missing, $fieldDef->{title} || "unnamed field" );
        }

        my $def;

        if( defined( $value ) ) {
            # NOTE: title and name are stored in the topic so that it can be
            # viewed without reading in the form definition
            $def =
              {
                  name =>  $fieldDef->{name},
                  title => $fieldDef->{title},
                  value => $value,
                  attributes => $fieldDef->{attributes},
              };
        } elsif( $preDef ) {
            $def = $preDef;
        }

        $meta->putKeyed( 'FIELD', $def ) if $def;
    }

    return ( $seen, \@missing );
}

=pod

---++ ObjectMethod isTextMergeable( $name ) -> $boolean

   * =$name= - name of a form field (value of the =name= attribute)

Returns true if the type of the named field allows it to be text-merged.

If the form does not define the field, it is assumed to be mergeable.

=cut

sub isTextMergeable {
    my( $this, $name ) = @_;

    my $fieldDef = $this->getField( $name );
    if( $fieldDef ) {
        return( $fieldDef->{type} !~ /^(checkbox|radio|select)/ );
    }
    # Field not found - assume it is mergeable
    return 1;
}

=pod

---++ ObjectMethod getField( $name ) -> \%row

   * =$name= - name of a form field (value of the =name= attribute)

Returns the field, or undef if the form does not define the field.

=cut

sub getField {
    my( $this, $name ) = @_;
    foreach my $fieldDef ( @{$this->{fields}} ) {
        return $fieldDef if ( $fieldDef->{name} && $fieldDef->{name} eq $name);
    }
    return undef;
}

=pod

---++ ObjectMethod getFields() -> \@fields

Return a list containing references to field name/value pairs.
Each entry in the list has a {name} field and a {value} field. It may
have other fields as well, which caller should ignore. The
returned list should be treated as *read only* (must not be written to).

=cut

sub getFields {
    my $this = shift;
    return $this->{fields};
}

=pod

---++ StaticMethod renderForDisplay($templates, $meta )

   * =$templates= ref to templates singleton
   * =$meta= - meta object containing the form to be rendered

Static because we want to be able to do this without a form definition.

SMELL: Why? Is reading the form topic such a big burden?

=cut

sub renderForDisplay {
    my( $templates, $meta ) = @_;
    my $form = $meta->get( 'FORM' );

    return '' unless( $form );

    $templates->readTemplate('formtables');

    my $name = $form->{name};

    my $text = $templates->expandTemplate('FORM:display:header');

	my $rowTemplate = $templates->expandTemplate('FORM:display:row');
    my @fields = $meta->find( 'FIELD' );
    foreach my $field ( @fields ) {
	my $fa = new TWiki::Attrs( $field->{attributes} || '', 1 );
        unless ( defined $fa->{'h'} || defined $fa->{'H'} ) {
            my $value = $field->{value};
            $value = '&nbsp;' unless defined($value);
            my $title = $field->{title} || $field->{name};
            my $row = $rowTemplate;
            $row =~ s/%A_TITLE%/$title/g;
            $row =~ s/%A_VALUE%/$value/g;
            $text .= $row;
        }
    }
    $text .= $templates->expandTemplate('FORM:display:footer');
    $text =~ s/%A_TITLE%/$name/g;
    return $text;
}

1;
