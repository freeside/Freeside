<%

$cgi->param('paynum') =~ /^(\d*)$/ or die "Illegal paynum!";
my $paynum = $1;

my $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } )
  or die "No such paynum";

my $cust_main = qsearchs('cust_main', { 'custnum' => $cust_pay->custnum } )
  or die "Bogus credit:  not attached to customer";

my $custnum = $cust_main->custnum;

my $new = new FS::cust_bill_pay ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(custnum _date amount invnum)
  } fields('cust_bill_pay')
} );

my $error = $new->insert;

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_bill_pay.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
}


%>
