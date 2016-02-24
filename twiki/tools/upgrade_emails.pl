#!perl
#
# This script will iterate over the list of users in the TWiki users
# topic, recovering the email for each user (which will get the email
# from the user topic if it isn't found in the secret DB) and then
# setting the email in the secret DB. This will *not* modify the
# user topics.
#
# A default admin e-mail address will be used for users without an 
# e-mail address currently in their user topic.
#

use strict;

my $admin_email = 'webmaster@example.com';
$/ = "\n";

print "Enter admin e-mail address to use as default, enter to confirm.\n";

while (1) {
    print "Admin e-mail address ['$admin_email']: ";
    my $n = <>;
    chomp $n;
    last if( !$n );
    $admin_email = $n;
};

BEGIN {
    require 'setlib.cfg';
};

use TWiki;

my $twiki = new TWiki();

my ($meta, $text) =
  $twiki->{store}->readTopic(
      undef, $TWiki::cfg{UsersWebName}, $TWiki::cfg{UsersTopicName} );

foreach my $line ( split( /\r?\n/, $text )) {
    if( $line =~ /^\s*\* ($TWiki::regex{webNameRegex}\.)?(\w+)\s*(?:-\s*(\S+)\s*)?-\s*\d+ \w+ \d+\s*$/o ) {
        my $web = $1 || $TWiki::cfg{UsersWebName};
        my $wn = $2;	# WikiName
        my $un = $3 || $wn;	# userid

        my $uo = $twiki->{users}->findUser( $un, $wn, 1 );

        if( $uo ) {
            my @em = $uo->emails();

            if( scalar( @em )) {
                print "Secreting ",$uo->stringify()," ",join(';',@em),"\n";
                $uo->setEmails( @em );
            } else {
                print "No email address found for user $un:$wn, using $admin_email\n";
                $uo->setEmails( "$admin_email" );
            }
        } else {
            print STDERR "$un:$wn is not a real user\n";
        }
    }
}

