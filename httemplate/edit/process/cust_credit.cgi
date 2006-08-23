%
%
%$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
%my $custnum = $1;
%
%my $new = new FS::cust_credit ( {
%  map {
%    $_, scalar($cgi->param($_));
%  } fields('cust_credit')
%} );
%
%my $error = $new->insert;
%
%if ( $error ) {
%  $cgi->param('error', $error);
%
%  
<% $cgi->redirect(popurl(2). "cust_credit.cgi?". $cgi->query_string ) %>
%
%
%} else {
%
%  if ( $cgi->param('apply') eq 'yes' ) {
%    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum })
%      or die "unknown custnum $custnum";
%    $cust_main->apply_credits;
%  }
%  #print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
%
%  
<% header('Credit sucessful') %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>

  </BODY></HTML>
% } 

