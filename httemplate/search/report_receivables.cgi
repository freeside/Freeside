<%

use strict;
use vars qw( $cgi );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);

$cgi = new CGI;
&cgisuidsetup($cgi);

print $cgi->header( '-expires' => '-2m' ),
      header('Current Receivables Report Results');

open (REPORT, "/usr/bin/freeside-receivables-report -v freeside |");

print '<PRE>';
while(<REPORT>) {
  print $_;
}
print '</PRE>';

print '</BODY></HTML>';

%>

