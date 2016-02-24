# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
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
# This is the EditTablePlugin used to edit tables in place.

package TWiki::Plugins::EditTablePlugin::Core;

use strict;
use Assert;

use vars qw(
            $preSp %params @format @formatExpanded
            $prefsInitialized $prefCHANGEROWS $prefEDITBUTTON
            $prefQUIETSAVE
            $nrCols $encodeStart $encodeEnd $table $query
           );

sub process {
    $query = TWiki::Func::getCgiQuery();
    TWiki::Func::writeDebug( "- EditTablePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $TWiki::Plugins::EditTablePlugin::debug;
    unless( $prefsInitialized ) {
        $prefCHANGEROWS           = TWiki::Func::getPreferencesValue('CHANGEROWS') ||
                    TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_CHANGEROWS') || 'on';
        $prefQUIETSAVE            = TWiki::Func::getPreferencesValue('QUIETSAVE') ||
                    TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_QUIETSAVE') || 'on';
        $prefEDITBUTTON           = TWiki::Func::getPreferencesValue('EDITBUTTON') ||
                    TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_EDITBUTTON') || 'Edit table';
        $prefsInitialized = 1;
    }

    my $theWeb = $_[2];
    my $theTopic = $_[1];
    my $result = '';
    my $tableNr = 0;
    my $rowNr = 0;
    my $enableForm = 0;
    my $insideTable = 0;
    my $doEdit = 0;
    my $cgiRows = -1;

    # appended stuff is a hack to handle EDITTABLE correctly if at end
    foreach( split( /\r?\n/, "$_[0]\n<nop>\n" ) ) {
        if( s/(\s*)%EDITTABLE{(.*)}%/&handleEditTableTag( $theWeb, $theTopic, $1, $2 )/geo ) {
            $enableForm = 1;
            $tableNr += 1;

            my $cgiTableNr = $query->param( 'ettablenr' ) || 0;
            $cgiRows = $query->param( 'etrows' ) || -1;
            if( ( $cgiTableNr == $tableNr ) && ( $theWeb.'.'.$theTopic eq "$TWiki::Plugins::EditTablePlugin::web.$TWiki::Plugins::EditTablePlugin::topic" ) ) {

               if( $query->param( 'etsave' ) ) {
                   # [Save table] button pressed
                   doSaveTable( $theWeb, $theTopic, $tableNr, '' );
                   ASSERT(0) if DEBUG;
                   return;
               } elsif( $query->param( 'etqsave' ) ) {
                   # [Quiet save] button pressed
                   doSaveTable( $theWeb, $theTopic, $tableNr, 'on' );
                   ASSERT(0) if DEBUG;
                   return;

               } elsif( $query->param( 'etcancel' ) ) {
                   # [Cancel] button pressed
                   doCancelEdit( $theWeb, $theTopic );
                   ASSERT(0) if DEBUG;
                   return;
                   return; # in case browser does not redirect

               } elsif( $query->param( 'etaddrow' ) ) {
                   # [Add row] button pressed
                   $cgiRows++ if( $cgiRows >= 0 );
                   $doEdit = doEnableEdit( $theWeb, $theTopic, 0 );
                   return unless( $doEdit );

               } elsif( $query->param( 'etdelrow' ) ) {
                   # [Delete row] button pressed
                   $cgiRows-- if( $cgiRows > 1 );
                   $doEdit = doEnableEdit( $theWeb, $theTopic, 0 );
                   return unless( $doEdit );

               } elsif( $query->param( 'etedit' ) ) {
                   # [Edit table] button pressed
                   $doEdit = doEnableEdit( $theWeb, $theTopic, 1 );
                   # never return if locked or no permission
                   return unless( $doEdit );
                   $cgiRows = -1; # make sure to get the actual number of rows
               }
            }
        }
        if( $enableForm ) {
            if( /^(\s*)\|.*\|\s*$/ ) {
                # found table row
                $result .= handleTableStart( $theWeb, $theTopic, $tableNr,
                                             $doEdit ) unless $insideTable;
                $insideTable = 1;
                $rowNr++;
                if( $doEdit && $cgiRows >= 0 && $rowNr > $cgiRows ) {
                    # deleted row
                    $rowNr--;
                    next;
                }
                s/^(\s*)\|(.*)/handleTableRow( $1, $2, $tableNr, $cgiRows, $rowNr, $doEdit, 0, $theWeb, $theTopic )/eo;

            } elsif( $insideTable ) {
                # end of table
                $insideTable = 0;
                if( $doEdit && $cgiRows >= 0 && $rowNr < $cgiRows ) {
                    while( $rowNr < $cgiRows ) {
                        $rowNr++;
                        $result .= handleTableRow(
                            '', '', $tableNr, $cgiRows, $rowNr, $doEdit,
                            0, $theWeb, $theTopic ) . "\n";
                    }
                }
                $result .= handleTableEnd( $theWeb, $rowNr, $doEdit );
                $enableForm = 0;
                $doEdit = 0;
                $rowNr = 0;
            }
            if( /^\s*$/ ) {      # empty line
                if( $enableForm ) {
                    # empty %EDITTABLE%, so create a default table
                    $result .= handleTableStart( $theWeb, $theTopic,
                                                 $tableNr, $doEdit );
                    $rowNr = 0;
                    if( $doEdit ) {
                       if( $params{'header'} ) {
                           $rowNr++;
                           $result .= handleTableRow(
                               $preSp, '', $tableNr, $cgiRows, $rowNr,
                               $doEdit, 0, $theWeb, $theTopic ) . "\n";
                        }
                        do {
                            $rowNr++;
                            $result .= handleTableRow(
                                $preSp, '', $tableNr, $cgiRows, $rowNr,
                                $doEdit, 0, $theWeb, $theTopic ) . "\n";
                        } while( $rowNr < $cgiRows );
                    }
                    $result .= handleTableEnd( $theWeb, $rowNr, $doEdit );
                    $enableForm = 0;
                }
                $doEdit = 0;
                $rowNr = 0;
            }
        }
        $result .= "$_\n";
    }
    # clean up hack that handles EDITTABLE correctly if at end
    $result =~ s|\n?<nop>\n$||o;

    $_[0] = $result;
}

sub extractParams {
    my( $theArgs, $theHashRef ) = @_;

    my $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'header' );
    $$theHashRef{'header'} = $tmp if( $tmp );

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'footer' );
    $$theHashRef{'footer'} = $tmp if( $tmp );

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'headerislabel' );
    $$theHashRef{'headerislabel'} = $tmp if( $tmp );

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'format' );
    $tmp =~ s/^\s*\|*\s*//o;
    $tmp =~ s/\s*\|*\s*$//o;
    $$theHashRef{'format'} = $tmp if( $tmp );

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'changerows' );
    $$theHashRef{'changerows'} = $tmp if( $tmp );

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'quietsave' );
    $$theHashRef{'quietsave'} = $tmp if( $tmp );

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'helptopic' );
    $$theHashRef{'helptopic'} = $tmp if( $tmp );

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'editbutton' );
    $$theHashRef{'editbutton'} = $tmp if( $tmp );

    return;
}

sub parseFormat {
    my( $theFormat, $theTopic, $theWeb, $doExpand ) = @_;

    $theFormat =~ s/\$nop(\(\))?//gos;      # remove filler
    $theFormat =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $theFormat =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $theFormat =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
    if( $doExpand ) {
        # expanded form to be able to use %-vars in format
        $theFormat =~ s/<nop>//gos;
        $theFormat = TWiki::Func::expandCommonVariables( $theFormat, $theTopic, $theWeb );
    }
    my @aFormat = split( /\s*\|\s*/, $theFormat );
    $aFormat[0] = "text,16" unless @aFormat;
    return @aFormat;
}

sub handleEditTableTag {
    my( $theWeb, $theTopic, $thePreSpace, $theArgs ) = @_;

    $preSp = $thePreSpace || '';
    %params = (
        'header'        => '',
        'footer'        => '',
        'headerislabel' => "1",
        'format'        => '',
        'changerows'    => $prefCHANGEROWS,
        'quietsave'     => $prefQUIETSAVE,
        'helptopic'     => '',
        'editbutton'    => '',
    );

    my $iTopic = TWiki::Func::extractNameValuePair( $theArgs, 'include' );
    if( $iTopic ) {
       # include topic to read definitions
       if( $iTopic =~ /^([^\.]+)\.(.*)$/o ) {
           $theWeb = $1;
           $iTopic = $2;
       }
       my $text = TWiki::Func::readTopicText( $theWeb, $iTopic );
       $text =~ /%EDITTABLE{(.*)}%/os;
       if( $1 ) {
           my $args = $1;
           if( $theWeb ne $TWiki::Plugins::EditTablePlugin::web || $iTopic ne $TWiki::Plugins::EditTablePlugin::topic ) {
               # expand common vars, unless oneself to prevent recursion
               $args = TWiki::Func::expandCommonVariables( $1, $iTopic, $theWeb );
           }
           extractParams( $args, \%params );
       }
    }

    extractParams( $theArgs, \%params );

    $params{'header'} = '' if( $params{header} =~ /^(off|no)$/oi );
    $params{'header'} =~ s/^\s*\|//o;
    $params{'header'} =~ s/\|\s*$//o;
    $params{'headerislabel'} = '' if( $params{headerislabel} =~ /^(off|no)$/oi );
    $params{'footer'} = '' if( $params{footer} =~ /^(off|no)$/oi );
    $params{'footer'} =~ s/^\s*\|//o;
    $params{'footer'} =~ s/\|\s*$//o;
    $params{'changerows'} = '' if( $params{changerows} =~ /^(off|no)$/oi );
    $params{'quietsave'}  = '' if( $params{quietsave}  =~ /^(off|no)$/oi );

    @format = parseFormat( $params{format}, $theTopic, $theWeb, 0 );
    @formatExpanded = parseFormat( $params{format}, $theTopic, $theWeb, 1 );
    $nrCols = @format;

    # FIXME: No handling yet of footer

    return "$preSp<nop>";
}

sub handleTableStart {
    my( $theWeb, $theTopic, $theTableNr, $doEdit ) = @_;

    my $viewUrl = TWiki::Func::getScriptUrl( $theWeb, $theTopic, 'viewauth' ) . "\#edittable$theTableNr";
    my $text = '';
    if( $doEdit ) {
        require TWiki::Contrib::JSCalendarContrib;
        unless( $@ ) {
            TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );
        }
    }
    $text .= "$preSp<noautolink>\n" if $doEdit;
    $text .= "$preSp<a name=\"edittable$theTableNr\"></a>\n";
    my $cssClass = 'editTable';
    if( $doEdit ) {
       $cssClass .= ' editTableEdit';
    }
    $text .= "<div class=\"".$cssClass."\">";
    $text .= "$preSp<form name=\"edittable$theTableNr\" action=\"$viewUrl\" method=\"post\">\n";
    $text .= "$preSp<input type=\"hidden\" name=\"ettablenr\" value=\"$theTableNr\" />\n";
    $text .= "$preSp<input type=\"hidden\" name=\"etedit\" value=\"on\" />\n" unless $doEdit;
    return $text;
}

sub handleTableEnd {
    my( $theWeb, $theRowNr, $doEdit ) = @_;

    my $text   = "$preSp<input type=\"hidden\" name=\"etrows\"   value=\"$theRowNr\" />\n";
    if( $doEdit ) {
        # Edit mode
        $text .= "$preSp<input type=\"submit\" name=\"etsave\"   value=\"Save table\" class=\"twikiSubmit\" />\n";
        if( $params{'quietsave'} ) {
            $text .= "$preSp<input type=\"submit\" name=\"etqsave\"  value=\"Quiet save\" class=\"twikiButton\" />\n";
        }
        if( $params{'changerows'} ) {
            $text .= "$preSp<input type=\"submit\" name=\"etaddrow\" value=\"Add row\" class=\"twikiButton\" />\n";
            $text .= "$preSp<input type=\"submit\" name=\"etdelrow\" value=\"Delete last row\" class=\"twikiButton\" />\n"
              unless( $params{'changerows'} =~ /^add$/oi );
        }
        $text .= "$preSp<input type=\"submit\" name=\"etcancel\" value=\"Cancel\" class=\"twikiButton\" />\n";

        if( $params{'helptopic'} ) {
            # read help topic and show below the table
            if( $params{'helptopic'} =~ /^([^\.]+)\.(.*)$/o ) {
                $theWeb = $1;
                $params{'helptopic'} = $2;
            }
            my $helpText = TWiki::Func::readTopicText( $theWeb, $params{'helptopic'} );
                        #Strip out the meta data so it won't be displayed.
            $helpText =~ s/%META:[A-Za-z0-9]+{.*?}%//g;
            if( $helpText ) {
                $helpText =~ s/.*?%STARTINCLUDE%//os;
                $helpText =~ s/%STOPINCLUDE%.*//os;
                $text .= $helpText;
            }
        }

    } else {
        # View mode
        if( $params{editbutton} eq "hide" ) {
            # do nothing, button assumed to be in a cell
        } else {
            # Add edit button to end of table
            $text .= $preSp . viewEditCell( "editbutton, 1, $params{'editbutton'}" );
        }
    }
    $text .= "$preSp</form>\n";
	$text .= "</div><!-- /editTable -->";
    $text .= "$preSp</noautolink>\n" if $doEdit;
    return $text;
}

sub parseEditCellFormat {
    $_[1] = TWiki::Func::extractNameValuePair( $_[0] );
    return '';
}

sub viewEditCell {
    my ( $theAttr ) = @_;
    $theAttr = TWiki::Func::extractNameValuePair( $theAttr );
    return '' unless( $theAttr =~ /^editbutton/ );

    $params{editbutton} = 'hide' unless( $params{editbutton} ); # Hide below table edit button

    my @bits  = split( /,\s*/, $theAttr );
    my $value = '';  $value = $bits[2] if( @bits > 2);
    my $img   = '';  $img   = $bits[3] if( @bits > 3);

    unless( $value ) {
        $value = $prefEDITBUTTON;
        $img = '';
        if( $value =~ s/(.+),\s*(.+)/$1/o ) {
            $img = $2;
            $img =~ s|%ATTACHURL%|%PUBURL%/%TWIKIWEB%/EditTablePlugin|o;
            $img =~ s|%WEB%|%TWIKIWEB%|o;
        }
    }

    if( $img ) {
        return "<input class=\"editTableEditImageButton\" type=\"image\" src=\"$img\" alt=\"$value\" />";
    } else {
        return "<input class=\"editTableEditButton\" type=\"submit\" value=\"$value\" />";
    }
}

sub saveEditCellFormat {
    my ( $theFormat, $theName ) = @_;
    return '' unless( $theFormat );
    $theName =~ s/cell/format/;
    return "<input type=\"hidden\" name=\"$theName\" value=\"$theFormat\" />";
}

sub inputElement {
    my ( $theTableNr, $theRowNr, $theCol, $theName, $theValue,
       $theWeb, $theTopic ) = @_;

    my $text = '';
    my $i = @format - 1;
    $i = $theCol if( $theCol < $i );
    my @bits = split( /,\s*/, $format[$i] );
    my @bitsExpanded = split( /,\s*/, $formatExpanded[$i] );

    my $cellFormat = '';
    $theValue =~ s/\s*%EDITCELL{(.*?)}%/&parseEditCellFormat( $1, $cellFormat )/eo;
    $theValue = '' if( $theValue eq ' ' );
    if( $cellFormat ) {
        my @aFormat = parseFormat( $cellFormat, $theTopic, $theWeb, 0);
        @bits = split( /,\s*/, $aFormat[0] );
        @aFormat = parseFormat( $cellFormat, $theTopic, $theWeb, 1);
        @bitsExpanded = split( /,\s*/, $aFormat[0] );
    }

    my $type = 'text';
    $type = $bits[0] if @bits > 0;
    # a table header is considered a label if read only header flag set
    $type = 'label' if( ( $params{'headerislabel'} ) && ( $theValue =~ /^\s*\*.*\*\s*$/ ) );
    $type = 'label' if( $type eq 'editbutton' );  # Hide [Edit table] button
    my $size = 0;
    $size = $bits[1] if @bits > 1;
    my $val  = '';
    my $valExpanded = '';
    my $sel  = '';
    my $style = '';
    $style = " style='background:#e8e8e8'" if ($theRowNr % 2);
    if( $type eq 'select' ) {
        my $expandedValue = TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
        $size = 1 if $size < 1;
        $text = "<select$style name=\"$theName\" size=\"$size\">";
        $i = 2;
        while( $i < @bits ) {
            $val  = $bits[$i] || '';
            $valExpanded  = $bitsExpanded[$i] || '';
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            if( $valExpanded eq $expandedValue ) {
                $text .= " <option selected=\"selected\">$val</option>";
            } else {
                $text .= " <option>$val</option>";
            }
            $i++;
        }
        $text .= " </select>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    } elsif( $type eq "radio" ) {
        my $expandedValue = &TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
        $size = 1 if $size < 1;
        my $elements = ( @bits - 2 );
        my $lines = $elements / $size;
        $lines = ($lines == int($lines)) ? $lines : int($lines + 1);
        $text .= "<table><tr><td valign=\"top\">" if( $lines > 1 );
        $i = 2;
        while( $i < @bits ) {
            $val  = $bits[$i] || "";
            $valExpanded  = $bitsExpanded[$i] || "";
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $text .= " <input type=\"radio\" name=\"$theName\" value=\"$val\"";
            $text .= " checked=\"checked\"" if( $valExpanded eq $expandedValue );
            $text .= " /> $val";
            if( $lines > 1 ) {
                if( ($i-1) % $lines ) {
                    $text .= " <br />";
                } elsif( $i-1 < $elements ) {
                    $text .= " </td><td valign=\"top\">";
                }
            }
            $i++;
        }
        $text .= "</td></tr></table>" if( $lines > 1 );
        $text .= saveEditCellFormat( $cellFormat, $theName );

     } elsif( $type eq "checkbox" ) {
        my $expandedValue = &TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
        $size = 1 if $size < 1;
        my $elements = ( @bits - 2 );
        my $lines = $elements / $size;
        my $names = "Chkbx:";
        $lines = ($lines == int($lines)) ? $lines : int($lines + 1);
        $text .= "<table><tr><td valign=\"top\">" if( $lines > 1 );
        $i = 2;
        while( $i < @bits ) {
            $val  = $bits[$i] || "";
            $valExpanded  = $bitsExpanded[$i] || "";
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $names .= " ${theName}x$i";
            $text .= " <input type=\"checkbox\" name=\"${theName}x$i\" value=\"$val\"";
            $text .= " checked=\"checked\"" if( $expandedValue =~ /(^|, )\Q$valExpanded\E(,|$)/ );
            $text .= " /> $val";
            if( $lines > 1 ) {
                if( ($i-1) % $lines ) {
                    $text .= " <br />";
                } elsif( $i-1 < $elements ) {
                    $text .= " </td><td valign=\"top\">";
                }
            }
            $i++;
        }
        $text .= "</td></tr></table>" if( $lines > 1 );
        $text .= " <input type=\"hidden\" name=\"$theName\" value=\"$names\" />";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    } elsif( $type eq 'row' ) {
        $size = $size + $theRowNr;
        $text = "$size<input type=\"hidden\" name=\"$theName\" value=\"$size\" />";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    } elsif( $type eq 'label' ) {
        # show label text as is, and add a hidden field with value
        my $isHeader = 0;
        $isHeader = 1 if( $theValue =~ s/^\s*\*(.*)\*\s*$/$1/o );
        $text = $theValue;

        # To optimize things, only in the case where a read-only column is
        # being processed (inside of this unless() statement) do we actually
        # go out and read the original topic.  Thus the reason for the
        # following unless() so we only read the topic the first time through.
        unless( defined $table ) {
            # To deal with the situation where TWiki variables, like
            # %CALC%, have already been processed and end up getting saved
            # in the table that way (processed), we need to read in the
            # topic page in raw format
            my $topicContents = TWiki::Func::readTopicText( $TWiki::Plugins::EditTablePlugin::web, $TWiki::Plugins::EditTablePlugin::topic );
            $table = TWiki::Plugins::Table->new( $topicContents );
        }
        my $cell = $table->getCell( $theTableNr, $theRowNr - 1, $theCol );
        $theValue = $cell if( defined $cell );  # original value from file
        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue( $theValue ) unless( $theValue eq '' );
        $theValue = "\*$theValue\*" if( $isHeader );
        $text .= "<input$style type=\"hidden\" name=\"$theName\" value=\"$theValue\" />";
        $text = "\*$text\*" if( $isHeader );

    } elsif( $type eq 'textarea' ) {
        my ($rows, $cols) = split( /x/, $size );
        $rows = 3 if $rows < 1;
        $cols = 30 if $cols < 1;

        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue( $theValue ) unless( $theValue eq '' );
        $text .= "<textarea$style class=\"editTableTextarea\" rows=\"$rows\" cols=\"$cols\" name=\"$theName\">$theValue</textarea>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    } elsif( $type eq 'date' ) {
        my $ifFormat = '';
        $ifFormat = $bits[3] if( @bits > 3 );
        $ifFormat ||= $TWiki::cfg{JSCalendarContrib}{format} || '%e %B %Y';
        $size = 10 if( !$size || $size < 1 );
        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue( $theValue ) unless( $theValue eq '' );
        $text .= CGI::textfield(
            { name => $theName,
              id => 'id'.$theName,
              size=> $size,
              value => $theValue });
        $text .= saveEditCellFormat( $cellFormat, $theName );
        eval 'use TWiki::Contrib::JSCalendarContrib';
        unless ( $@ ) {
            $text .= CGI::image_button(
                -name => 'calendar',
                -onclick =>
                  "return showCalendar('id$theName','$ifFormat')",
                -src=> TWiki::Func::getPubUrlPath() . '/' .
                  TWiki::Func::getTwikiWebname() .
                      '/JSCalendarContrib/img.gif',
                -alt => 'Calendar',
                -align => 'MIDDLE' );
        }

        $query->{'jscalendar'} = 1;

    } else { #  if( $type eq 'text')
        $size = 16 if $size < 1;
        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue( $theValue ) unless( $theValue eq '' );
        $text = "<input$style class=\"editTableInput\" type=\"text\" name=\"$theName\" size=\"$size\" value=\"$theValue\" />";
        $text .= saveEditCellFormat( $cellFormat, $theName );
    }
    return $text;
}

sub handleTableRow {
    my ( $thePre, $theRow, $theTableNr, $theRowMax, $theRowNr, $doEdit, $doSave, $theWeb, $theTopic ) = @_;

    $thePre = '' unless( defined( $thePre ) );
    my $text = "$thePre\|";

    if( $doEdit ) {
        $theRow =~ s/\|\s*$//o;
        my @cells = split( /\|/, $theRow );
        my $tmp = @cells;
        $nrCols = $tmp if( $tmp > $nrCols );  # expand number of cols
        my $val = '';
        my $cellFormat = '';
        my $cell = '';
        my $cellDefined = 0;
        my $col = 0;
        while( $col < $nrCols ) {
            $col += 1;
            $cellDefined = 0;
            $val = $query->param( "etcell${theRowNr}x$col" );
            if( $val && $val =~ /^Chkbx: (etcell.*)/ ) {
                # Multiple checkboxes, val has format "Chkbx: etcell4x2x2 etcell4x2x3 ..."
                my $chkBoxeNames = $1;
                my $chkBoxVals = "";
                foreach( split( /\s/, $chkBoxeNames ) ) {
                    $val = $query->param( $_ );
                    $chkBoxVals .= "$val, " if( defined $val );
                }
                $chkBoxVals =~ s/, $//;
                $val = $chkBoxVals;
            }
            $cellFormat = $query->param( "etformat${theRowNr}x$col" );
            $val .= " %EDITCELL{$cellFormat}%" if( $cellFormat );
            if( defined $val ) {
                # change any new line character sequences to <br />
                $val =~ s/(\n\r?)|(\r\n?)+/<br \/>/gos;
                # escape "|" to HTML entity
                $val =~ s/\|/\&\#124;/gos;
                $cellDefined = 1;
                # Expand %-vars
                $cell = $val;
            } elsif( $col <= @cells ) {
                $cell = $cells[$col-1];
                $cellDefined = 1 if( length( $cell ) > 0 );
                $cell =~ s/^\s//o;
                $cell =~ s/\s$//o;
            } else {
                $cell = '';
            }
            if( ( $theRowNr <= 1 ) && ( $params{'header'} ) ) {
                unless( $cell ) {
                    if( $params{'header'} =~ /^on$/i ) {
                        if( ( @format >= $col ) && ( $format[$col-1] =~ /(.*?)\,/ ) ) {
                            $cell = $1;
                        }
                        $cell = 'text' unless $cell;
                        $cell = "*$cell*";
                    } else {
                        my @hCells = split( /\|/, $params{'header'} );
                        $cell = $hCells[$col-1] if( @hCells >= $col );
                        $cell = "*text*" unless $cell;
                    }
                }
                $text .= "$cell\|";

            } elsif( $doSave ) {
                $text .= " $cell \|";

            } else {
                if( ( ! $cellDefined ) && ( @format >= $col )
                 && ( $format[$col-1] =~ /^\s*(.*?)\,\s*(.*?)\,\s*(.*?)\s*$/ ) ) {
                     # default value of "| text, 20, a, b, c |" cell is "a, b, c"
                     # default value of '| select, 1, a, b, c |' cell is "a"
                     $val = $1;  # type
                     $cell = $3;
                     $cell = '' unless( defined $cell && $cell ne '' ); # Proper handling of '0'
                     $cell =~ s/\,.*$//o if( $val eq 'select' || $val eq 'date' );
                }
                $text .= inputElement( $theTableNr, $theRowNr, $col-1, "etcell${theRowNr}x$col", $cell, $theWeb, $theTopic ) . " \|";
            }
        }
    } else {
        $theRow =~ s/%EDITCELL{(.*?)}%/viewEditCell($1)/geo;
        $text .= $theRow;
    }
    return $text;
}

sub doSaveTable {
    my ( $theWeb, $theTopic, $theTableNr, $quiet ) = @_;

    TWiki::Func::writeDebug( "- EditTablePlugin::doSaveTable( $theWeb, $theTopic, $theTableNr, $quiet )" ) if $TWiki::Plugins::EditTablePlugin::debug;

    my $text = TWiki::Func::readTopicText( $theWeb, $theTopic );

    my $cgiRows = $query->param( 'etrows' ) || 1;
    my $tableNr = 0;
    my $rowNr = 0;
    my $insideTable = 0;
    my $doSave = 0;
    my $result = '';
    # appended stuff is a hack to handle EDITTABLE correctly if at end
    foreach( split( /\r?\n/, "$text\n<nop>\n" ) ) {
        if( /%EDITTABLE{(.*)}%/o ) {
            $tableNr += 1;
            if( $tableNr == $theTableNr ) {
               $doSave = 1;
            }
        }
        if( $doSave ) {
            if( /^(\s*)\|.*\|\s*$/ ) {
                $insideTable = 1;
                $rowNr++;
                if( $rowNr > $cgiRows ) {
                    # deleted row
                    $rowNr--;
                    next;
                }
                s/^(\s*)\|(.*)/&handleTableRow( $1, $2, $tableNr, $cgiRows, $rowNr, 1, 1, $theWeb, $theTopic )/eo;

            } elsif( $insideTable ) {
                $insideTable = 0;
                if( $rowNr < $cgiRows ) {
                    while( $rowNr < $cgiRows ) {
                        $rowNr++;
                        $result .= handleTableRow( $preSp, '', $tableNr, $cgiRows, $rowNr, 1, 1, $theWeb, $theTopic ) . "\n";
                    }
                }
                $doSave = 0;
                $rowNr = 0;
            }
            if( /^\s*$/ ) {      # empty line
                if( $doSave ) {
                    # empty %EDITTABLE%, so create a default table
                    $rowNr = 0;
                    if( $params{'header'} ) {
                        $rowNr++;
                        $result .= handleTableRow( $preSp, '', $tableNr, $cgiRows, $rowNr,1 , 1, $theWeb, $theTopic ) . "\n";
                    }
                    while( $rowNr < $cgiRows ) {
                        $rowNr++;
                        $result .= handleTableRow( $preSp, '', $tableNr, $cgiRows, $rowNr, 1, 1, $theWeb, $theTopic ) . "\n";
                    }
                }
                $doSave = 0;
                $rowNr = 0;
            }
        }
        $result .= "$_\n";
    }
    $result =~ s|\n<nop>\n$||o; # clean up hack that handles EDITTABLE correctly if at end

    my $error = TWiki::Func::saveTopicText( $theWeb, $theTopic, $result, '', $quiet );
    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 0 );  # unlock Topic
    my $url = TWiki::Func::getViewUrl( $theWeb, $theTopic );
    if( $error ) {
        $url = TWiki::Func::getOopsUrl( $theWeb, $theTopic, 'oopssaveerr', $error );
    }
    TWiki::Func::redirectCgiQuery( $query, $url );
}

sub doCancelEdit {
    my ( $theWeb, $theTopic ) = @_;

    TWiki::Func::writeDebug( "- EditTablePlugin::doCancelEdit( $theWeb, $theTopic )" ) if $TWiki::Plugins::EditTablePlugin::debug;

    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 0 );

    TWiki::Func::redirectCgiQuery( $query, TWiki::Func::getViewUrl( $theWeb, $theTopic ) );
}

sub doEnableEdit {
    my ( $theWeb, $theTopic, $doCheckIfLocked ) = @_;

    TWiki::Func::writeDebug( "- EditTablePlugin::doEnableEdit( $theWeb, $theTopic )" ) if $TWiki::Plugins::EditTablePlugin::debug;

    my $wikiUserName = TWiki::Func::getWikiUserName();
    if( ! TWiki::Func::checkAccessPermission( 'change', $wikiUserName, undef, $theTopic, $theWeb ) ) {
        # user has no permission to change the topic
        throw TWiki::OopsException(
            'accessdenied',
            def => 'topic_access',
            web => $theWeb, topic => $theTopic,
            params => [ 'change', 'denied' ] );
    }

    my $breakLock = $query->param( 'breaklock' ) || '';
    unless( $breakLock ) {
      my( $oopsUrl, $lockUser ) = TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'view' );
      if ( $oopsUrl ) {
        my $loginUser = TWiki::Func::wikiToUserName($wikiUserName);
        if ($lockUser  ne  $loginUser) {
          # warn user that other person is editing this topic
          TWiki::Func::redirectCgiQuery( $query, $oopsUrl, 1 );
          return 0;
        }
      }
    }
    # We are allowed to edit
    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );

    return 1;
}

# SMELL: The following code is copied from the ChartPlugin Table object.

package TWiki::Plugins::Table;

sub new {
    my ($class, $topicContents) = @_;
    my $this = {};
    bless $this, $class;
    $this->_parseOutTables($topicContents);
    return $this;
}

# The guts of this routine was initially copied from SpreadSheetPlugin.pm
# and were used in the ChartPlugin Table object which this was copied from,
# but this has been modified to support the functionality needed by the
# EditTablePlugin.  One major change is to only count and save tables
# following an %EDITTABLE{.*}% tag.
#
# This routine basically returns an array of hashes where each hash
# contains the information for a single table.  Thus the first hash in the
# array represents the first table found on the topic page, the second hash
# in the array represents the second table found on the topic page, etc.
sub _parseOutTables {
    my ($this, $topic) = @_;
    my $tableNum = 1;           # Table number (only count tables with EDITTABLE tag)
    my @tableMatrix;            # Currently parsed table.

    my $inEditTable = 0;        # Flag to keep track if in an EDITTABLE table
    my $result = '';
    my $insidePRE = 0;
    my $insideTABLE = 0;
    my $line = '';
    my @row = ();

    $topic =~ s/\r//go;
    $topic =~ s/\\\n//go;  # Join lines ending in "\"
    foreach( split( /\n/, $topic ) ) {

        # change state:
        m|<pre\b|i      && ( $insidePRE = 1 );
        m|<verbatim\b|i && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if( ! $insidePRE ) {
            $inEditTable = 1 if (/%EDITTABLE{(.*)}%/);
            if ($inEditTable) {
                if( /^\s*\|.*\|\s*$/ ) {
                    # inside | table |
                    $insideTABLE = 1;
                    $line = $_;
                    $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o; # Remove starting '|'
                    @row  = split( /\|/o, $line, -1 );
                    _trim(\@row);
                    push (@tableMatrix, [ @row ]);

                } else {
                    # outside | table |
                    if( $insideTABLE ) {
                        # We were inside a table and are now outside of it so
                        # save the table info into the Table object.
                        $insideTABLE = 0;
                        $inEditTable = 0;
                        if (@tableMatrix != 0) {
                            # Save the table via its table number
                            $$this{"TABLE_$tableNum"} = [@tableMatrix];
                            $tableNum++;
                        }
                        undef @tableMatrix;  # reset table matrix
                        $result .= '</div>';
                    }
                }
            }
        }
        $result .= "$_\n";
    }
    $$this{NUM_TABLES} = $tableNum;
}

# Trim any leading and trailing white space and/or '*'.
sub _trim {
    my ($totrim) = @_;
    for my $element (@$totrim) {
        $element =~ s/^[\s\*]+//;       # Strip of leading white/*
        $element =~ s/[\s\*]+$//;       # Strip of trailing white/*
    }
}

# Return the contents of the specified cell
sub getCell {
    my ( $this, $tableNum, $row, $column ) = @_;

    my @selectedTable = $this->getTable( $tableNum );
    my $value = $selectedTable[$row][$column];
    return $value;
}

sub getTable {
    my ($this, $tableNumber) = @_;
    my $table = $$this{"TABLE_$tableNumber"};
    return @$table if defined( $table );
    return ();
}

1;
