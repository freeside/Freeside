<%
#<!-- $Id: cust_credit.cgi,v 1.3 2001-12-26 04:25:04 ivan Exp $ -->

use strict;
use vars qw( $cgi $custnum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(popurl);
use FS::Record qw(fields);
use FS::cust_credit;

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
$custnum = $1;

$cgi->param('otaker',getotaker);

$new = new FS::cust_credit ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(custnum _date amount otaker reason)
  } fields('cust_credit')
} );

$error=$new->insert;

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_credit.cgi?". $cgi->query_string );
} else {
  if ( $cgi->param('apply') eq 'yes' ) {
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum })
      or die "unknown custnum $linknum";
    $cust_main->apply_payments;
  }
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
}


%>
