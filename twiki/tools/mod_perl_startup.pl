$ENV{MOD_PERL} =~ /mod_perl/ or die "mod_perl_startup called, but mod_perl not used!";
use lib qw( /var/www/html/wiki.tdwg.org/twiki/bin );
require 'setlib.cfg';
1;
