<!-- mason kludge -->
<% include("/elements/header.html","Credit card batch details", menubar( 'Main Menu' => $p,)) %>
%
%
%die "No batch specified (bad URL)!" unless $cgi->keywords;
%my($query) = $cgi->keywords;
%$query =~ /^(\d+)$/;
%my $batchnum = $1;
%my $pay_batch = qsearchs('pay_batch',{'batchnum'=>$batchnum});
%die "Batch not found!" unless $pay_batch;
%
%


<FORM ACTION="<%$p%>misc/download-batch.cgi" METHOD="POST">
Download batch in format <SELECT NAME="format">
<OPTION VALUE="">Default batch mode</OPTION>
<OPTION VALUE="csv-td_canada_trust-merchant_pc_batch">CSV file for TD Canada Trust Merchant PC Batch</OPTION>
<OPTION VALUE="PAP">80 byte file for TD Canada Trust PAP Batch</OPTION>
<OPTION VALUE="BoM">Bank of Montreal ECA batch</OPTION>
</SELECT><INPUT TYPE="hidden" NAME="batchnum" VALUE="<% $batchnum %>"><INPUT TYPE="submit" VALUE="Download"></FORM>
<BR><BR>

<FORM ACTION="<%$p%>misc/upload-batch.cgi" METHOD="POST" ENCTYPE="multipart/form-data">
Upload results<BR>
Filename <INPUT TYPE="file" NAME="batch_results"><BR>
Format <SELECT NAME="format">
<OPTION VALUE="">Default batch mode</OPTION>
<OPTION VALUE="csv-td_canada_trust-merchant_pc_batch">CSV results from TD Canada Trust Merchant PC Batch</OPTION>
<OPTION VALUE="PAP">264 byte results for TD Canada Trust PAP Batch</OPTION>
<OPTION VALUE="BoM">Bank of Montreal ECA results</OPTION>
</SELECT><BR>
<INPUT TYPE="submit" VALUE="Upload"></FORM>
<BR>
%
%  my $statement = "SELECT SUM(amount) from cust_pay_batch WHERE batchnum=".
%                     $batchnum;
%  my $sth = dbh->prepare($statement) or die dbh->errstr. "doing $statement";
%  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;
%  my $total = $sth->fetchrow_arrayref->[0];
%
%  my $c_statement = "SELECT COUNT(*) from cust_pay_batch WHERE batchnum=".
%                       $batchnum;
%  my $c_sth = dbh->prepare($c_statement)
%    or die dbh->errstr. "doing $c_statement";
%  $c_sth->execute or die "Error executing \"$c_statement\": ". $c_sth->errstr;
%  my $cards = $c_sth->fetchrow_arrayref->[0];
%

<% $cards %> credit card payments batched<BR>
$<% sprintf("%.2f", $total) %> total in batch<BR>

<BR>
<% &table() %>
      <TR>
        <TH>#</TH>
        <TH><font size=-1>inv#</font></TH>
        <TH COLSPAN=2>Customer</TH>
        <TH>Card name</TH>
        <TH>Card</TH>
        <TH>Exp</TH>
        <TH>Amount</TH>
        <TH>Status</TH>
      </TR>
%
%foreach my $cust_pay_batch ( sort { $a->paybatchnum <=> $b->paybatchnum }
%                             qsearch('cust_pay_batch', {'batchnum'=>$batchnum} )
%) {
%  my $cardnum = $cust_pay_batch->payinfo;
%  #$cardnum =~ s/.{4}$/xxxx/;
%  $cardnum = 'x'x(length($cardnum)-4). substr($cardnum,(length($cardnum)-4));
%
%  $cust_pay_batch->exp =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
%  my( $mon, $year ) = ( $2, $1 );
%  $mon = "0$mon" if $mon < 10;
%  my $exp = "$mon/$year";
%
%


      <TR>
        <TD><% $cust_pay_batch->paybatchnum %></TD>
        <TD><A HREF="../view/cust_bill.cgi?<% $cust_pay_batch->invnum %>"><% $cust_pay_batch->invnum %></TD>
        <TD><A HREF="../view/cust_main.cgi?<% $cust_pay_batch->custnum %>"><% $cust_pay_batch->custnum %></TD>
        <TD><% $cust_pay_batch->get('last'). ', '. $cust_pay_batch->first %></TD>
        <TD><% $cust_pay_batch->payname %></TD>
        <TD><% $cardnum %></TD>
        <TD><% $exp %></TD>
        <TD align="right">$<% $cust_pay_batch->amount %></TD>
        <TD><% $cust_pay_batch->status %></TD>
      </TR>
% } 


    </TABLE>
  </BODY>
</HTML>
