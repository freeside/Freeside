% if ( $link eq 'popup' ) { 
  <% include('/elements/header-popup.html', $title ) %>
% } else { 
  <% include("/elements/header.html", $title, '') %>
% } 

<% include('/elements/error.html') %>

% unless ( $link eq 'popup' ) { 
    <% small_custview($custnum, $conf->config('countrydefault')) %>
% } 

<FORM NAME="RefundForm" ACTION="<% $p1 %>process/cust_refund.cgi" METHOD=POST onSubmit="document.RefundForm.submitButton.disabled=true">
<INPUT TYPE="hidden" NAME="popup" VALUE="<% $link %>">
<INPUT TYPE="hidden" NAME="refundnum" VALUE="">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="paynum" VALUE="<% $paynum %>">
<INPUT TYPE="hidden" NAME="_date" VALUE="<% $_date %>">
<INPUT TYPE="hidden" NAME="payby" VALUE="<% $payby %>">
<INPUT TYPE="hidden" NAME="paybatch" VALUE="">
<INPUT TYPE="hidden" NAME="credited" VALUE="">

<BR>

% if ( $cust_pay ) {
%
%  #false laziness w/FS/FS/cust_pay.pm
%  my $payby = FS::payby->payname($cust_pay->payby);
%  my $paymask = $cust_pay->paymask;
%  my $paydate = $cust_pay->paydate;
%  if ( $cgi->param('error') ) { 
%    $paydate = $cgi->param('exp_year'). '-'. $cgi->param('exp_month'). '-01';
%    $paydate = '' unless ($paydate =~ /^\d{2,4}-\d{1,2}-01$'/);
%  }

  <BR><B>Payment</B>
  <% ntable("#cccccc", 2) %>

    <TR>
      <TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">$<% $cust_pay->paid %></TD>
    </TR>

  <TR>
    <TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff"><% time2str($date_format, $cust_pay->_date) %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Method</TD><TD BGCOLOR="#ffffff"><% $payby %> # <% $paymask %></TD>
  </TR>

% unless ( $paydate || $cust_pay->payby ne 'CARD' ) {  # possibly other reasons: i.e. card has since expired
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
% if ( $cust_pay->processor ) {
    <TR>
      <TD ALIGN="right">Processor</TD>
      <TD BGCOLOR="#ffffff"><% $cust_pay->processor %></TD>
    </TR>
% if ( length($cust_pay->auth) ) { 

      <TR>
        <TD ALIGN="right">Authorization</TD>
        <TD BGCOLOR="#ffffff"><% $cust_pay->auth %></TD>
      </TR>
% } 
% if ( length($cust_pay->order_number) ) { 

      <TR>
        <TD ALIGN="right">Order number</TD>
        <TD BGCOLOR="#ffffff"><% $cust_pay->order_number %></TD>
      </TR>
% } 
% } # if ($cust_pay->processor)

  </TABLE>
% }  #if $cust_pay


<BR><B>Refund</B>
<% ntable("#cccccc", 2) %>

  <TR>
    <TD ALIGN="right">Date</TD>
    <TD BGCOLOR="#ffffff"><% time2str($date_format, $_date) %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Amount</TD>
    <TD BGCOLOR="#ffffff">$<INPUT TYPE="text" NAME="refund" VALUE="<% $refund %>" SIZE=8 MAXLENGTH=9></TD>
  </TR>

% if ( $payby eq 'BILL' ) { 
    <TR>
      <TD ALIGN="right">Check </TD>
      <TD><INPUT TYPE="text" NAME="payinfo" VALUE="<% $payinfo %>" SIZE=10></TD>
    </TR>
% }
% elsif ($payby eq 'CHEK' || $payby eq 'CARD') {

  <TR>
    <TD ALIGN="right">Method</TD>
    <TD BGCOLOR="#ffffff"><% FS::payby->payname($real_payby) %> # <% $real_paymask %></TD>
  </TR>

% if ($payby eq "CARD" || $payby eq "DCRD") {
          <INPUT TYPE="hidden" NAME="batch" VALUE="">
% }
% elsif ( $conf->exists("batch-enable")
%      || grep $payby eq $_, $conf->config('batch-enable_payby')
% ) {
%     if ( grep $payby eq $_, $conf->config('realtime-disable_payby') ) {
          <INPUT TYPE="hidden" NAME="batch" VALUE="1">
%     } else {
        <TR>
          <TD ALIGN="right"><INPUT TYPE="checkbox" NAME="batch" VALUE="1" ID="batch" <% ($batchnum || $batch) ? 'checked' : '' %> ></TD>
          <TD ALIGN="left">&nbsp;&nbsp;&nbsp;<% mt('Add to current batch') |h %></TD>
        </TR>
%     }
%  }

% } else {
    <INPUT TYPE="hidden" NAME="payinfo" VALUE="">
% }

<& /elements/tr-select-reason.html,
              'field'          => 'reasonnum',
              'reason_class'   => 'F',
              'control_button' => "confirm_refund_button",
              'cgi'            => $cgi,
&>

</TABLE>

<BR>
<INPUT TYPE="submit" NAME="submitButton" ID="confirm_refund_button" VALUE="<% mt('Post refund') |h %>" DISABLED>

</FORM>

% if ( $link eq 'popup' ) { 
    </BODY>
    </HTML>
% } else { 
    <% include('/elements/footer.html') %>
% } 

<%init>

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my $custnum = $cgi->param('custnum');
my $refund  = $cgi->param('refund');
my $payby   = $cgi->param('payby');
my $payinfo = $cgi->param('payinfo');
my $reason  = $cgi->param('reason');
my $link    = $cgi->param('popup') ? 'popup' : '';
my $batch   = $cgi->param('batch');

die "access denied"
  unless $FS::CurrentUser::CurrentUser->refund_access_right($payby);

my( $paynum, $cust_pay, $batchnum ) = ( '', '', '' );
if ( $cgi->param('paynum') =~ /^(\d+)$/ ) {
  $paynum = $1;
  $cust_pay = qsearchs('cust_pay', { paynum=>$paynum } )
    or die "unknown payment # $paynum";
  $refund ||= $cust_pay->unrefunded;
  $batchnum = $cust_pay->batchnum;
  if ( $custnum ) {
    die "payment # $paynum is not for specified customer # $custnum"
      unless $custnum == $cust_pay->custnum;
  } else {
    $custnum = $cust_pay->custnum;
  }
}
die "no custnum or paynum specified!" unless $custnum;

my $cust_main = qsearchs( 'cust_main', { 'custnum'=>$custnum } );
die "unknown custnum $custnum" unless $cust_main;

my $real_payby = $cust_main->payby;
my $real_paymask = $cust_main->paymask;

my $_date = time;

my $p1 = popurl(1);

my $title = 'Refund '. FS::payby->payname($payby). ' payment';

</%init>
