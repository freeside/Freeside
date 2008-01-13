%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "cust_bill_pay.cgi?". $cgi->query_string ) %>
%} else {
<% header('Payment application sucessful') %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY>
  </HTML>
% } 
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply payment') #;
      || $FS::CurrentUser::CurrentUser->access_right('Post payment'): #remove after 1.7.3

$cgi->param('paynum') =~ /^(\d*)$/ or die "Illegal paynum!";
my $paynum = $1;

my $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } )
  or die "No such paynum";

my $cust_main = qsearchs('cust_main', { 'custnum' => $cust_pay->custnum } )
  or die "Bogus credit:  not attached to customer";

my $custnum = $cust_main->custnum;

my $new;
if ($cgi->param('invnum') =~ /^Refund$/) {
  $new = new FS::cust_refund ( {
    'reason'  => 'Refunding payment', #enter reason in UI
    'refund'  => $cgi->param('amount'),
    'payby'   => 'BILL',
    #'_date'   => $cgi->param('_date'),
    'payinfo' => 'Cash', #enter payinfo in UI
    'paynum' => $paynum,
  } );
} else {
  $new = new FS::cust_bill_pay ( {
    map {
      $_, scalar($cgi->param($_));
    #} qw(custnum _date amount invnum)
    } fields('cust_bill_pay')
  } );
}

my $error = $new->insert;

</%init>
