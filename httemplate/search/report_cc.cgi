<%

use strict;
use vars qw( $cgi $user $beginning $ending );
use CGI;
use CGI::Carp qw( fatalsToBrowser );
use FS::UID qw( cgisuidsetup getotaker );
use FS::CGI qw( header );

$cgi = new CGI;
&cgisuidsetup($cgi);

$user = getotaker;

$cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
$beginning = $1;

$cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
$ending = $1;

print $cgi->header( '-expires' => '-2m' ),
  header('Credit Card Recipt Report Results');

open (REPORT, "/usr/bin/freeside-cc-receipts-report -v -s $beginning -d $ending $user |");

print '<PRE>';
while(<REPORT>) {
  print $_;
}
print '</PRE>';

print '</BODY></HTML>';

%>

