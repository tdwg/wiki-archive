package TWiki::Contrib::JSCalendarContrib;

use vars qw( $VERSION $RELEASE );

use TWiki;

# This should always be $Rev: 11704 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11704 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# Helper for plugins, to add the requisite bits of the calendar
# to the header
sub addHEAD {
    my $setup = shift;
    $setup ||= 'calendar-setup';
    my $style = $TWiki::cfg{JSCalendarContrib}{style} || 'blue';
    my $lang = $TWiki::cfg{JSCalendarContrib}{lang} || 'en';
    my $base = '%PUBURLPATH%/%TWIKIWEB%/JSCalendarContrib';
    my $head = <<HERE;
<style type='text/css' media='all'>
  \@import url('$base/calendar-$style.css');
  .calendar {z-index:2000;}
</style>
<script type='text/javascript' src='$base/calendar.js'></script>
<script type='text/javascript' src='$base/lang/calendar-$lang.js'></script>
HERE
    TWiki::Func::addToHEAD( 'JSCALENDAR_HEAD', $head );

    # Add the setup separately; there might be different setups required
    # in a single HTML page.
    $head = <<HERE;
<script type='text/javascript' src='$base/$setup.js'></script>
HERE
    TWiki::Func::addToHEAD( 'JSCALENDAR_HEAD'.$setup, $head );
}

1;
