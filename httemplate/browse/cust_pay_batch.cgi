<!-- mason kludge -->
<%= header("Pending credit card batch", menubar( 'Main Menu' => $p,)) %>

<FORM ACTION="<%=$p%>misc/download-batch.cgi" METHOD="POST">

Download batch in format <SELECT NAME="format">
<OPTION VALUE="csv">Generic CSV (comma-separated value)</OPTION>
<OPTION VALUE="csv-td_canada_trust-merchant_pc_batch">CSV file for TD Canada Trust Merchant PC Batch</OPTION>
</SELECT><INPUT TYPE="submit" VALUE="Download">
<BR><BR>

<%= &table() %>
      <TR>
        <TH>#</TH>
        <TH><font size=-1>inv#</font></TH>
        <TH COLSPAN=2>Customer</TH>
        <TH>Card name</TH>
        <TH>Card</TH>
        <TH>Exp</TH>
        <TH>Amount</TH>
      </TR>

<%
foreach my $cust_pay_batch ( sort { $a->paybatchnum <=> $b->paybatchnum }
                             qsearch('cust_pay_batch', {} )
) {
  my $cardnum = $cust_pay_batch->cardnum;
  #$cardnum =~ s/.{4}$/xxxx/;
  $cardnum = 'x'x(length($cardnum)-4). substr($cardnum,(length($cardnum)-4));

  $cust_pay_batch->exp =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
  my( $mon, $year ) = ( $2, $1 );
  $mon = "0$mon" if $mon < 10;
  my $exp = "$mon/$year";

%>

      <TR>
        <TD><%= $cust_pay_batch->paybatchnum %></TD>
        <TD><A HREF="../view/cust_bill.cgi?<%= $cust_pay_batch->invnum %>"><%= $cust_pay_batch->invnum %></TD>
        <TD><A HREF="../view/cust_main.cgi?<%= $cust_pay_batch->custnum %>"><%= $cust_pay_batch->custnum %></TD>
        <TD><%= $cust_pay_batch->get('last'). ', '. $cust_pay_batch->first %></TD>
        <TD><%= $cust_pay_batch->payname %></TD>
        <TD><%= $cardnum %></TD>
        <TD><%= $exp %></TD>
        <TD align="right">$<%= $cust_pay_batch->amount %></TD>
      </TR>

<% } %>

    </TABLE>
  </BODY>
</HTML>
