<!-- mason kludge -->
<%

my $conf = new FS::Conf;

my($link, $linknum, $paid, $payby, $payinfo, $quickpay); 
if ( $cgi->param('error') ) {
  $link = $cgi->param('link');
  $linknum = $cgi->param('linknum');
  $paid = $cgi->param('paid');
  $payby = $cgi->param('payby');
  $payinfo = $cgi->param('payinfo');
  $quickpay = $cgi->param('quickpay');
} elsif ($cgi->keywords) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $link = 'invnum';
  $linknum = $1;
  $paid = '';
  $payby = 'BILL';
  $payinfo = "";
  $quickpay = '';
} elsif ( $cgi->param('custnum')  =~ /^(\d+)$/ ) {
  $link = 'custnum';
  $linknum = $1;
  $paid = '';
  $payby = 'BILL';
  $payinfo = '';
  $quickpay = $cgi->param('quickpay');
} else {
  die "illegal query ". $cgi->keywords;
}
my $_date = time;

my $paybatch = "webui-$_date-$$-". rand() * 2**32;

my $p1 = popurl(1);
print header("Post payment", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT><BR><BR>"
  if $cgi->param('error');

print <<END, ntable("#cccccc",2);
    <FORM ACTION="${p1}process/cust_pay.cgi" METHOD=POST>
    <INPUT TYPE="hidden" NAME="link" VALUE="$link">
    <INPUT TYPE="hidden" NAME="linknum" VALUE="$linknum">
    <INPUT TYPE="hidden" NAME="quickpay" VALUE="$quickpay">
END

my $custnum;
if ( $link eq 'invnum' ) {

  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $linknum } )
    or die "unknown invnum $linknum";
  print "Invoice #<B>$linknum</B>". ntable("#cccccc",2).
        '<TR><TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff">'.
        time2str("%D", $cust_bill->_date). '</TD></TR>'.
        '<TR><TD ALIGN="right" VALIGN="top">Items</TD><TD BGCOLOR="#ffffff">';
  foreach ( $cust_bill->cust_bill_pkg ) { #false laziness with FS::cust_bill
    if ( $_->pkgnum ) {

      my($cust_pkg)=qsearchs('cust_pkg', { 'pkgnum', $_->pkgnum } );
      my($part_pkg)=qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->pkgpart});
      my($pkg)=$part_pkg->pkg;

      if ( $_->setup != 0 ) {
        print "$pkg Setup<BR>"; # $money_char. sprintf("%10.2f",$_->setup);
        print join('<BR>',
          map { "  ". $_->[0]. ": ". $_->[1] } $cust_pkg->labels
        ). '<BR>';
      }

      if ( $_->recur != 0 ) {
        print
          "$pkg (" . time2str("%x",$_->sdate) . " - " .
                                time2str("%x",$_->edate) . ")<BR>";
          #$money_char. sprintf("%10.2f",$_->recur)
        print join('<BR>',
          map { '--->'. $_->[0]. ": ". $_->[1] } $cust_pkg->labels
        ). '<BR>';
      }

    } else { #pkgnum Tax
      print "Tax<BR>" # $money_char. sprintf("%10.2f",$_->setup)
        if $_->setup != 0;
    }

  }
  print '</TD></TR></TABLE><BR><BR>';

  $custnum = $cust_bill->custnum;

} elsif ( $link eq 'custnum' ) {
  $custnum = $linknum;
}

print small_custview($custnum, $conf->config('countrydefault'));

print qq!<INPUT TYPE="hidden" NAME="_date" VALUE="$_date">!;
print qq!<INPUT TYPE="hidden" NAME="payby" VALUE="$payby">!;

print '<BR><BR>Payment'. ntable("#cccccc", 2).
      '<TR><TD ALIGN="right">Date</TD><TD BGCOLOR="#ffffff">'.
      time2str("%D",$_date).  '</TD></TR>';

print qq!<TR><TD ALIGN="right">Amount</TD><TD BGCOLOR="#ffffff">\$<INPUT TYPE="text" NAME="paid" VALUE="$paid" SIZE=8 MAXLENGTH=8></TD></TR>!;

print qq!<TR><TD ALIGN="right">Payby</TD><TD BGCOLOR="#ffffff">$payby</TD></TR>!;

#payinfo (check # now as payby="BILL" hardcoded.. what to do later?)
print qq!<TR><TD ALIGN="right">Check #</TD><TD BGCOLOR="#ffffff"><INPUT TYPE="text" NAME="payinfo" VALUE="$payinfo"></TD></TR>!;

print qq!<TR><TD ALIGN="right">Auto-apply<BR>to invoices</TD><TD><SELECT NAME="apply"><OPTION VALUE="yes" SELECTED>yes<OPTION>no</SELECT></TD>!;

print "</TABLE>";

#paybatch
print qq!<INPUT TYPE="hidden" NAME="paybatch" VALUE="$paybatch">!;

print <<END;
<BR>
<INPUT TYPE="submit" VALUE="Post payment">
    </FORM>
  </BODY>
</HTML>
END

%>
