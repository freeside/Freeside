<!-- mason kludge -->
<%

my $conf = new FS::Conf;

my($link, $linknum, $paid, $payby, $payinfo, $quickpay, $_date); 
if ( $cgi->param('error') ) {
  $link     = $cgi->param('link');
  $linknum  = $cgi->param('linknum');
  $paid     = $cgi->param('paid');
  $payby    = $cgi->param('payby');
  $payinfo  = $cgi->param('payinfo');
  $quickpay = $cgi->param('quickpay');
  $_date    = $cgi->param('_date') ? str2time($cgi->param('_date')) : time;
} elsif ($cgi->keywords) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $link     = 'invnum';
  $linknum  = $1;
  $paid     = '';
  $payby    = 'BILL';
  $payinfo  = "";
  $quickpay = '';
  $_date    = time;
} elsif ( $cgi->param('custnum')  =~ /^(\d+)$/ ) {
  $link     = 'custnum';
  $linknum  = $1;
  $paid     = '';
  $payby    = 'BILL';
  $payinfo  = '';
  $quickpay = $cgi->param('quickpay');
  $_date    = time;
} else {
  die "illegal query ". $cgi->keywords;
}

my $paybatch = "webui-$_date-$$-". rand() * 2**32;

%>

<%=  header("Post payment", '') %>

<% if ( $cgi->param('error') ) { %>
<FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
<BR><BR>
<% } %>

<%= ntable("#cccccc",2) %>

<LINK REL="stylesheet" TYPE="text/css" HREF="../elements/calendar-win2k-2.css" TITLE="win2k-2">
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar_stripped.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-en.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-setup.js"></SCRIPT>

<FORM ACTION="<%= popurl(1) %>process/cust_pay.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="link" VALUE="<%= $link %>">
<INPUT TYPE="hidden" NAME="linknum" VALUE="<%= $linknum %>">
<INPUT TYPE="hidden" NAME="quickpay" VALUE="<%= $quickpay %>">

<% 
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
%>

<%= small_custview($custnum, $conf->config('countrydefault')) %>

<INPUT TYPE="hidden" NAME="payby" VALUE="<%= $payby %>">

<BR><BR>
Payment
<%= ntable("#cccccc", 2) %>
<TR>
  <TD ALIGN="right">Date</TD>
  <TD COLSPAN=2>
    <INPUT TYPE="text" NAME="_date" ID="_date_text" VALUE="<%= time2str("%m/%d/%Y %r",$_date) %>">
    <IMG SRC="../images/calendar.png" ID="_date_button" STYLE="cursor: pointer" TITLE="Select date">
  </TD>
</TR>
<SCRIPT TYPE="text/javascript">
  Calendar.setup({
    inputField: "_date_text",
    ifFormat:   "%m/%d/%Y",
    button:     "_date_button",
    align:      "BR"
  });
</SCRIPT>
<TR>
  <TD ALIGN="right">Amount</TD>
  <TD BGCOLOR="#ffffff" ALIGN="right">$</TD>
  <TD><INPUT TYPE="text" NAME="paid" VALUE="<%= $paid %>" SIZE=8 MAXLENGTH=8></TD>
</TR>
<TR>
  <TD ALIGN="right">Check #</TD>
  <TD COLSPAN=2><INPUT TYPE="text" NAME="payinfo" VALUE="<%= $payinfo %>" SIZE=10></TD>
</TR>
<TR>
  <TD ALIGN="right">Auto-apply<BR>to invoices</TD>
  <TD COLSPAN=2><SELECT NAME="apply"><OPTION VALUE="yes" SELECTED>yes<OPTION>no</SELECT></TD>
</TR>

</TABLE>

<INPUT TYPE="hidden" NAME="paybatch" VALUE="<%= $paybatch %>">

<BR>
<INPUT TYPE="submit" VALUE="Post payment">
    </FORM>
  </BODY>
</HTML>
