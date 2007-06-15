%
%
%my $conf = new FS::Conf;
%my $custnum = $cgi->param('custnum');
%my $refund  = $cgi->param('refund');
%my $payby   = $cgi->param('payby');
%my $reason  = $cgi->param('reason');
%
%my( $paynum, $cust_pay ) = ( '', '' );
%if ( $cgi->param('paynum') =~ /^(\d+)$/ ) {
%  $paynum = $1;
%  $cust_pay = qsearchs('cust_pay', { paynum=>$paynum } )
%    or die "unknown payment # $paynum";
%  $refund ||= $cust_pay->unrefunded;
%  if ( $custnum ) {
%    die "payment # $paynum is not for specified customer # $custnum"
%      unless $custnum == $cust_pay->custnum;
%  } else {
%    $custnum = $cust_pay->custnum;
%  }
%}
%die "no custnum or paynum specified!" unless $custnum;
%
%my $_date = time;
%
%my $p1 = popurl(1);
%
%


<% include('/elements/header.html', 'Refund '. ucfirst(lc($payby)). ' payment', '') %>
% if ( $cgi->param('error') ) { 

  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% } 


<% small_custview($custnum, $conf->config('countrydefault')) %>

<FORM NAME="RefundForm" ACTION="<% $p1 %>process/cust_refund.cgi" METHOD=POST onSubmit="document.RefundForm.submit.disabled=true">
<INPUT TYPE="hidden" NAME="refundnum" VALUE="">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="paynum" VALUE="<% $paynum %>">
<INPUT TYPE="hidden" NAME="_date" VALUE="<% $_date %>">
<INPUT TYPE="hidden" NAME="payby" VALUE="<% $payby %>">
<INPUT TYPE="hidden" NAME="payinfo" VALUE="">
<INPUT TYPE="hidden" NAME="paybatch" VALUE="">
<INPUT TYPE="hidden" NAME="credited" VALUE="">
<BR>
% if ( $cust_pay ) {
%
%  #false laziness w/FS/FS/cust_pay.pm
%  my $payby = $cust_pay->payby;
%  my $paymask = $cust_pay->paymask;
%  my $paydate = $cust_pay->paydate;
%  if ( $cgi->param('error') ) { 
%    $paydate = $cgi->param('exp_year'). '-'. $cgi->param('exp_month'). '-01';
%    $paydate = '' unless ($paydate =~ /^\d{2,4}-\d{1,2}-01$'/);
%  }
%  $payby =~ s/^BILL$/Check/ if $paymask;
%  $payby =~ s/^CHEK$/Electronic check/;
%
%


  <BR>Payment
  <% ntable("#cccccc", 2) %>

    <TR>
      <TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">$<% $cust_pay->paid %></TD>
    </TR>

  <TR>
    <TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff"><% time2str("%D",$cust_pay->_date) %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Method</TD><TD BGCOLOR="#ffffff"><% ucfirst(lc($payby)) %> # <% $paymask %></TD>
  </TR>

% unless ( $paydate ) {  # possibly other reasons: i.e. card has since expired
  <TR>
    <TD ALIGN="right">Expiration</TD><TD BGCOLOR="#ffffff">
      <% include( '/elements/select-month_year.html',
                  'prefix' => 'exp',
                  'selected_date' => $paydate,
                  'empty_option' => !$paydate,
                ) %>
    </TD>
  </TR>
% } 

%
%  #false laziness w/FS/FS/cust_main::realtime_refund_bop
%  if ( $cust_pay->paybatch =~ /^(\w+):(\w+)(:(\w+))?$/ ) {
%    my ( $processor, $auth, $order_number ) = ( $1, $2, $4 );
%  


    <TR>
      <TD ALIGN="right">Processor</TD><TD BGCOLOR="#ffffff"><% $processor %></TD>
    </TR>
% if ( length($auth) ) { 

      <TR>
        <TD ALIGN="right">Authorization</TD><TD BGCOLOR="#ffffff"><% $auth %></TD>
      </TR>
% } 
% if ( length($order_number) ) { 

      <TR>
        <TD ALIGN="right">Order number</TD><TD BGCOLOR="#ffffff"><% $order_number %></TD>
      </TR>
% } 
% } 

  </TABLE>
% } 


<BR>Refund
<% ntable("#cccccc", 2) %>

  <TR>
    <TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff"><% time2str("%D",$_date) %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">$<INPUT TYPE="text" NAME="refund" VALUE="<% $refund %>" SIZE=8 MAXLENGTH=8></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Reason</TD><TD BGCOLOR="#ffffff"><INPUT TYPE="text" NAME="reason" VALUE="<% $reason %>"></TD>
  </TR>
</TABLE>

<BR>
<INPUT TYPE="submit" NAME="submit" VALUE="Post refund">

</FORM>

<% include('/elements/footer.html') %>

