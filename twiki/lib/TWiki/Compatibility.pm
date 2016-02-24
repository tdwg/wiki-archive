# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 TWiki Contributors.
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

package TWiki::Compatibility;

=pod

---+ package TWiki::Compatibility

Support for compatibility with old TWiki versions. Packaged
separately because 99.999999% of the time this won't be needed.

=cut

sub _upgradeCategoryItem {
    my ( $catitems, $ctext ) = @_;
    my $catname = '';
    my $scatname = '';
    my $catmodifier = '';
    my $catvalue = '';
    my @cmd = split( /\|/, $catitems );
    my $src = '';
    my $len = @cmd;
    if( $len < '2' ) {
        # FIXME
        return ( $catname, $catmodifier, $catvalue )
    }
    my $svalue = '';

    my $i;
    my $itemsPerLine;

    # check for CategoryName=CategoryValue parameter
    my $paramCmd = '';
    my $cvalue = ''; # was$query->param( $cmd[1] );
    if( $cvalue ) {
        $src = "<!---->$cvalue<!---->";
    } elsif( $ctext ) {
        foreach( split( /\r?\n/, $ctext ) ) {
            if( /$cmd[1]/ ) {
                $src = $_;
                last;
            }
        }
    }

    if( $cmd[0] eq 'select' || $cmd[0] eq 'radio') {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        my $size = $cmd[2];
        for( $i = 3; $i < $len; $i++ ) {
            my $value = $cmd[$i];
            $svalue = $value;
            if( $src =~ /$value/ ) {
               $catvalue = $svalue;
            }
        }

    } elsif( $cmd[0] eq 'checkbox' ) {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        if( $cmd[2] eq 'true' || $cmd[2] eq '1' ) {
            $i = $len - 4;
            $catmodifier = 1;
        }
        $itemsPerLine = $cmd[3];
        for( $i = 4; $i < $len; $i++ ) {
            my $value = $cmd[$i];
            $svalue = $value;
            # I18N: FIXME - need to look at this, but since it's upgrading
            # old forms that probably didn't use I18N, it's not a high
            # priority.
            if( $src =~ /$value[^a-zA-Z0-9\.]/ ) {
                $catvalue .= ", " if( $catvalue );
                $catvalue .= $svalue;
            }
        }

    } elsif( $cmd[0] eq 'text' ) {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        $src =~ /<!---->(.*)<!---->/;
        if( $1 ) {
            $src = $1;
        } else {
            $src = '';
        }
        $catvalue = $src;
    }

    return ( $catname, $catmodifier, $catvalue )
}

=pod

---++ StaticMethod upgradeCategoryTable( $session, $web, $topic, $meta, $text ) -> $text

Upgrade old style category table

May throw TWiki::OopsException

=cut

sub upgradeCategoryTable {
    my( $session, $web, $topic, $meta, $text ) = @_;

    my $icat = $session->{templates}->readTemplate( 'twikicatitems' );

    if( $icat ) {
        my @items = ();
        # extract category section and build category form elements
        my( $before, $ctext, $after) = split( /<!--TWikiCat-->/, $text );
        # cut TWikiCat part
        $text = $before || '';
        $text .= $after if( $after );
        $ctext = '' if( ! $ctext );

        my $ttext = '';
        foreach( split( /\r?\n/, $icat ) ) {
            my( $catname, $catmod, $catvalue ) = _upgradeCategoryItem( $_, $ctext );
            if( $catname ) {
                push @items, ( [$catname, $catmod, $catvalue] );
            }
        }
        my $prefs = $session->{prefs};
        my $listForms = $prefs->getWebPreferencesValue( 'WEBFORMS', $web );
        $listForms =~ s/^\s*//go;
        $listForms =~ s/\s*$//go;
        my @formTemplates = split( /\s*,\s*/, $listForms );
        my $defaultFormTemplate = '';
        $defaultFormTemplate = $formTemplates[0] if ( @formTemplates );

        if( ! $defaultFormTemplate ) {
            $session->writeWarning( "Form: can't get form definition to convert category table " .
                                  " for topic $web.$topic" );
            foreach my $oldCat ( @items ) {
                my $name = $oldCat->[0];
                my $value = $oldCat->[2];
                $meta->put( 'FORM', { name => '' } );
                $meta->putKeyed( 'FIELD',
                            { name => $name,
                              title => $name,
                              value => $value
                            } );
            }
            return;
        }

        my $def = new TWiki::Form($session, $web, $defaultFormTemplate );
        $meta->put( 'FORM', { name => $defaultFormTemplate } );

        foreach my $fieldDef ( @{$def->{fields}} ) {
            my $value = '';
            foreach my $oldCatP ( @items ) {
                my @oldCat = @$oldCatP;
                my $name = $oldCat[0] || '';
                $name =~ s/[^A-Za-z0-9_\.]//go;
                if( $name eq $fieldDef->{name} ) {
                    $value = $oldCat[2];
                    last;
                }
            }
            $meta->putKeyed( 'FIELD',
                             {
                              name => $fieldDef->{name},
                              title => $fieldDef->{title},
                              value => $value,
                             } );
        }

    } else {
        $session->writeWarning( "Form: get find category template twikicatitems for Web $web" );
    }
    return $text;
}

1;
