%if ( $success ) {
<& /elements/header-popup.html, mt("Credit voided") &>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY>
</HTML>
%} else {
<& /elements/header-popup.html, mt('Void credit')  &>

<& /elements/error.html &>

<P ALIGN="center"><B><% mt('Void this credit?') |h %></B>

<FORM action="<% ${p} %>misc/void-cust_credit.cgi">
<INPUT TYPE="hidden" NAME="crednum" VALUE="<% $crednum %>">

<TABLE BGCOLOR="#cccccc" BORDER="0" CELLSPACING="2" STYLE="margin-left:auto; margin-right:auto">
<& /elements/tr-select-reason.html,
             'field'          => 'reasonnum',
             'reason_class'   => 'X',
             'cgi'            => $cgi
&>
</TABLE>

<BR>
<P ALIGN="CENTER">
<INPUT TYPE="submit" NAME="confirm_void_credit" VALUE="<% mt('Void credit') |h %>"> 
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<INPUT TYPE="BUTTON" VALUE="<% mt("Don't void credit") |h %>" onClick="parent.cClick();"> 

</FORM>
</BODY>
</HTML>

%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Void credit');

#untaint crednum
my $crednum = $cgi->param('crednum');
if ($crednum) {
  $crednum =~ /^(\d+)$/ || die "Illegal crednum";
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)/ || die "Illegal crednum";
  $crednum = $1;
}

my $cust_credit = qsearchs('cust_credit',{'crednum'=>$crednum}) || die "Credit not found";

my $success = 0;
if ($cgi->param('confirm_void_credit')) {

  #untaint reasonnum / create new reason
  my ($reasonnum, $error) = $m->comp('process/elements/reason');
  if (!$reasonnum) {
    $error = 'Reason required';
  } else {
    my $reason = qsearchs('reason', { 'reasonnum' => $reasonnum })
      || die "Reason num $reasonnum not found in database";
	$error = $cust_credit->void($reason) unless $error;
  }

  if ($error) {
    $cgi->param('error',$error);
  } else {
    $success = 1;
  }
}

</%init>
