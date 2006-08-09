<!-- mason kludge -->
<%= include("/elements/header.html","Credit card batches", menubar( 'Main Menu' => $p,)) %>

<BR><BR>

<%
  my %statusmap = ('I'=>'In Transit', 'O'=>'Open', 'R'=>'Resolved');
%>

<BR>
<%= &table() %>
      <TR>
        <TH>Batch</TH>
        <TH>First Download</TH>
        <TH>Last Upload</TH>
        <TH>Item Count</TH>
        <TH>Amount</TH>
        <TH>Status</TH>
      </TR>

<%
foreach my $pay_batch ( sort { $b->batchnum <=> $a->batchnum }
                             qsearch('pay_batch', {} )
) {

  my $statement = "SELECT SUM(amount) from cust_pay_batch WHERE batchnum=" .
                     $pay_batch->batchnum;
  my $sth = dbh->prepare($statement) or die dbh->errstr. "doing $statement";
  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;
  my $total = $sth->fetchrow_arrayref->[0];

  my $c_statement = "SELECT COUNT(*) from cust_pay_batch WHERE batchnum=" .
                       $pay_batch->batchnum;
  my $c_sth = dbh->prepare($c_statement)
    or die dbh->errstr. "doing $c_statement";
  $c_sth->execute or die "Error executing \"$c_statement\": ". $c_sth->errstr;
  my $cards = $c_sth->fetchrow_arrayref->[0];

%>

      <TR>
        <TD><A HREF="cust_pay_batch.cgi?<%= $pay_batch->batchnum %>"><%= $pay_batch->batchnum %></TD>
        <TD><%= $pay_batch->download ? time2str("%a %b %e %T %Y", $pay_batch->download) : '' %></TD>
        <TD><%= $pay_batch->upload ? time2str("%a %b %e %T %Y", $pay_batch->upload) : '' %></TD>
        <TD><%= $cards %></TD>
        <TD align="right"><%= $total %></TD>
        <TD><%= $statusmap{$pay_batch->status} %></TD>
      </TR>

<% } %>

    </TABLE>
  </BODY>
</HTML>
