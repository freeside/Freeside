%if ( $success ) {
<& /elements/header-popup.html, mt("Payment voided") &>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY>
</HTML>
%} else {
<& /elements/header-popup.html, mt('Void payment')  &>

<& /elements/error.html &>

<P ALIGN="center"><B><% mt('Void this payment?') |h %></B>

<FORM action="<% ${p} %>misc/void-cust_pay.cgi">
<INPUT TYPE="hidden" NAME="paynum" VALUE="<% $paynum %>">

<TABLE BGCOLOR="#cccccc" BORDER="0" CELLSPACING="2" STYLE="margin-left:auto; margin-right:auto">
<& /elements/tr-select-reason.html,
             'field'          => 'reasonnum',
             'reason_class'   => 'X',
             'cgi'            => $cgi
&>
</TABLE>

<BR>
<P ALIGN="CENTER">
<INPUT TYPE="submit" NAME="confirm_void_payment" VALUE="<% mt('Void payment') |h %>"> 
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<INPUT TYPE="BUTTON" VALUE="<% mt("Don't void payment") |h %>" onClick="parent.cClick();"> 

</FORM>
</BODY>
</HTML>

%}
<%init>

#untaint paynum
my $paynum = $cgi->param('paynum');
if ($paynum) {
  $paynum =~ /^(\d+)$/ || die "Illegal paynum";
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)/ || die "Illegal paynum";
  $paynum = $1;
}

my $cust_pay = qsearchs('cust_pay',{'paynum'=>$paynum}) || die "Payment not found";

my $right = 'Void payments';
$right = 'Credit card void' if $cust_pay->payby eq 'CARD';
$right = 'Echeck void'      if $cust_pay->payby eq 'CHEK';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right($right);

my $success = 0;
if ($cgi->param('confirm_void_payment')) {

  #untaint reasonnum / create new reason
  my ($reasonnum, $error) = $m->comp('process/elements/reason');
  if (!$reasonnum) {
    $error = 'Reason required';
  } else {
    my $reason = qsearchs('reason', { 'reasonnum' => $reasonnum })
      || die "Reason num $reasonnum not found in database";
	$error = $cust_pay->void($reason) unless $error;
  }

  if ($error) {
    $cgi->param('error',$error);
  } else {
    $success = 1;
  }
}

</%init>
