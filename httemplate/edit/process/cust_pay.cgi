<%
#<!-- $Id: cust_pay.cgi,v 1.5 2001-12-26 05:19:01 ivan Exp $ -->

use strict;
use vars qw( $cgi $link $linknum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(fields);
use FS::cust_pay;

$cgi = new CGI;
&cgisuidsetup($cgi);

$cgi->param('linknum') =~ /^(\d+)$/
  or die "Illegal linknum: ". $cgi->param('linknum');
$linknum = $1;

$cgi->param('link') =~ /^(custnum|invnum)$/
  or die "Illegal link: ". $cgi->param('link');
$link = $1;

$new = new FS::cust_pay ( {
  $link => $linknum,
  map {
    $_, scalar($cgi->param($_));
  } qw(paid _date payby payinfo paybatch)
  #} fields('cust_pay')
} );

$error = $new->insert;

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). 'cust_pay.cgi?'. $cgi->query_string );
  exit;
} elsif ( $link eq 'invnum' ) {
  print $cgi->redirect(popurl(3). "view/cust_bill.cgi?$linknum");
} elsif ( $link eq 'custnum' ) {
  if ( $cgi->param('apply') eq 'yes' ) {
    my $cust_main = qsearchs('cust_main', { 'custnum' => $linknum })
      or die "unknown custnum $linknum";
    $cust_main->apply_payments;
  }
  if ( $cgi->param('quickpay') eq 'yes' ) {
    print $cgi->redirect(popurl(3). "search/cust_main-quickpay.html");
  } else {
    print $cgi->redirect(popurl(3). "view/cust_main.cgi?$linknum");
  }
}

%>
