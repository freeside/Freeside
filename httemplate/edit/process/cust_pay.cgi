<%
#<!-- $Id: cust_pay.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $invnum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(fields);
use FS::cust_pay;

$cgi = new CGI;
&cgisuidsetup($cgi);

$cgi->param('invnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
$invnum = $1;

$new = new FS::cust_pay ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(invnum paid _date payby payinfo paybatch)
  } fields('cust_pay')
} );

$error=$new->insert;

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). 'cust_pay.cgi?'. $cgi->query_string );
  exit;
} else {
  print $cgi->redirect(popurl(3). "view/cust_bill.cgi?$invnum");
}

%>
