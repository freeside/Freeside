<%
#<!-- $Id: cust_bill_pay.cgi,v 1.1 2001-12-18 19:30:31 ivan Exp $ -->

use strict;
use vars qw( $cgi $custnum $paynum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(popurl);
use FS::Record qw(qsearchs fields);
use FS::cust_pay;
use FS::cust_bill_pay;
use FS::cust_main;

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('paynum') =~ /^(\d*)$/ or die "Illegal paynum!";
$paynum = $1;

my $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } )
  or die "No such paynum";

my $cust_main = qsearchs('cust_main', { 'custnum' => $cust_pay->custnum } )
  or die "Bogus credit:  not attached to customer";

my $custnum = $cust_main->custnum;

$new = new FS::cust_bill_pay ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(custnum _date amount invnum)
  } fields('cust_bill_pay')
} );

$error=$new->insert;

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_bill_pay.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
}


%>
