%
%
%$cgi->param('crednum') =~ /^(\d*)$/ or die "Illegal crednum!";
%my $crednum = $1;
%
%my $cust_credit = qsearchs('cust_credit', { 'crednum' => $crednum } )
%  or die "No such crednum";
%
%my $cust_main = qsearchs('cust_main', { 'custnum' => $cust_credit->custnum } )
%  or die "Bogus credit:  not attached to customer";
%
%my $custnum = $cust_main->custnum;
%
%my $new;
%if ($cgi->param('invnum') =~ /^Refund$/) {
%  $new = new FS::cust_refund ( {
%    'reason'  => ( $cust_credit->reason || 'refund from credit' ),
%    'refund'  => $cgi->param('amount'),
%    'payby'   => 'BILL',
%    #'_date'   => $cgi->param('_date'),
%    #'payinfo' => 'Cash',
%    'payinfo' => 'Refund',
%    'crednum' => $crednum,
%  } );
%} else {
%  $new = new FS::cust_credit_bill ( {
%    map {
%      $_, scalar($cgi->param($_));
%    #} qw(custnum _date amount invnum)
%    } fields('cust_credit_bill')
%  } );
%}
%
%my $error = $new->insert;
%
%if ( $error ) {
%
%  $cgi->param('error', $error);
%  
<% $cgi->redirect(popurl(2). "cust_credit_bill.cgi?". $cgi->query_string ) %>
%
%
%} else {
%
%  #print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
%
%  
<% header('Credit application sucessful') %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>

  </BODY></HTML>
% } 

