<!-- $Id: cust_credit.cgi,v 1.6 2002-01-30 14:18:08 ivan Exp $ -->
<%

$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
my $custnum = $1;

$cgi->param('otaker',getotaker);

my $new = new FS::cust_credit ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(custnum _date amount otaker reason)
  } fields('cust_credit')
} );

my $error = $new->insert;

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_credit.cgi?". $cgi->query_string );
} else {
  if ( $cgi->param('apply') eq 'yes' ) {
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum })
      or die "unknown custnum $custnum";
    $cust_main->apply_credits;
  }
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
}


%>
