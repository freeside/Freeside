<!-- mason kludge -->
<%

my $conf = new FS::Conf;
my $custnum = $cgi->param('custnum');
my $refund  = $cgi->param('refund');
my $payby   = $cgi->param('payby');
my $reason  = $cgi->param('reason');

my( $paynum, $cust_pay ) = ( '', '' );
if ( $cgi->param('paynum') =~ /^(\d+)$/ ) {
  $paynum = $1;
  $cust_pay = qsearchs('cust_pay', { paynum=>$paynum } )
    or die "unknown payment # $paynum";
  $refund ||= $cust_pay->unrefunded;
  if ( $custnum ) {
    die "payment # $paynum is not for specified customer # $custnum"
      unless $custnum == $cust_pay->custnum;
  } else {
    $custnum = $cust_pay->custnum;
  }
}
die "no custnum or paynum specified!" unless $custnum;

my $_date = time;

my $p1 = popurl(1);

print header('Refund '. ucfirst(lc($payby)). ' payment', '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');
print <<END, small_custview($custnum, $conf->config('countrydefault'));
    <FORM ACTION="${p1}process/cust_refund.cgi" METHOD=POST>
    <INPUT TYPE="hidden" NAME="refundnum" VALUE="">
    <INPUT TYPE="hidden" NAME="custnum" VALUE="$custnum">
    <INPUT TYPE="hidden" NAME="paynum" VALUE="$paynum">
    <INPUT TYPE="hidden" NAME="_date" VALUE="$_date">
    <INPUT TYPE="hidden" NAME="payby" VALUE="$payby">
    <INPUT TYPE="hidden" NAME="payinfo" VALUE="">
    <INPUT TYPE="hidden" NAME="paybatch" VALUE="">
    <INPUT TYPE="hidden" NAME="credited" VALUE="">
    <BR>
END

if ( $cust_pay ) {

  #false laziness w/FS/FS/cust_pay.pm
  my $payby = $cust_pay->payby;
  my $payinfo = $cust_pay->payinfo;
  $payby =~ s/^BILL$/Check/ if $payinfo;
  $payby =~ s/^CHEK$/Electronic check/;
  $payinfo = $cust_pay->payinfo_masked if $payby eq 'CARD';

  print '<BR>Payment'. ntable("#cccccc", 2).
        '<TR><TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">$'.
          $cust_pay->paid. '</TD></TR>'.
        '<TR><TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff">'.
          time2str("%D",$cust_pay->_date). '</TD></TR>'.
        '<TR><TD ALIGN="right">Method</TD><TD BGCOLOR="#ffffff">'.
          ucfirst(lc($payby)). ' # '. $payinfo. '</TD></TR>';
  #false laziness w/FS/FS/cust_main::realtime_refund_bop
  if ( $cust_pay->paybatch =~ /^(\w+):(\w+)(:(\w+))?$/ ) {
    my ( $processor, $auth, $order_number ) = ( $1, $2, $4 );
    print '<TR><TD ALIGN="right">Processor</TD><TD BGCOLOR="#ffffff">'.
          $processor. '</TD></TR>';
    print '<TR><TD ALIGN="right">Authorization</TD><TD BGCOLOR="#ffffff">'.
          $auth. '</TD></TR>'
      if length($auth);
    print '<TR><TD ALIGN="right">Order number</TD><TD BGCOLOR="#ffffff">'.
          $order_number. '</TD></TR>'
      if length($order_number);
  }
  print '</TABLE>';
}

print '<BR>Refund'. ntable("#cccccc", 2).
      '<TR><TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff">'.
      time2str("%D",$_date). '</TD></TR>';

print qq!<TR><TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">\$<INPUT TYPE="text" NAME="refund" VALUE="$refund" SIZE=8 MAXLENGTH=8></TD></TR>!;

print qq!<TR><TD ALIGN="right">Reason</TD><TD BGCOLOR="#ffffff"><INPUT TYPE="text" NAME="reason" VALUE="$reason"></TD></TR>!;

print <<END;
</TABLE>
<BR>
<INPUT TYPE="submit" VALUE="Post refund">
    </FORM>
  </BODY>
</HTML>
END

%>
