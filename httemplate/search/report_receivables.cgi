<%

use strict;
use vars qw( $cgi $user );
use CGI;
use CGI::Carp qw( fatalsToBrowser );
use FS::UID qw( cgisuidsetup getotaker );

$cgi = new CGI;
&cgisuidsetup($cgi);

$user = getotaker;

print $cgi->header( '-expires' => '-2m' ),
  header('Current Receivables Report Results');

open (REPORT, "freeside-receivables-report -v $user |");

print '<PRE>';
while(<REPORT>) {
  print $_;
}
print '</PRE>';

print '</BODY></HTML>';

%>

