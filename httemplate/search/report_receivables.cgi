<!-- mason kludge -->
<%

  my $charged = <<END;
  sum( charged
       - coalesce(
           ( select sum(amount) from cust_bill_pay
             where cust_bill.invnum = cust_bill_pay.invnum )
           ,0
         )
       - coalesce(
           ( select sum(amount) from cust_credit_bill
             where cust_bill.invnum = cust_credit_bill.invnum )
           ,0
         )

     )
END

  my $owed_cols = <<END;
       coalesce(
         ( select $charged from cust_bill
           where cust_bill._date > extract(epoch from now())-2592000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_0_30,

       coalesce(
         ( select $charged from cust_bill
           where cust_bill._date >  extract(epoch from now())-5184000
             and cust_bill._date <= extract(epoch from now())-2592000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_30_60,

       coalesce(
         ( select $charged from cust_bill
           where cust_bill._date >  extract(epoch from now())-7776000
             and cust_bill._date <= extract(epoch from now())-5184000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_60_90,

       coalesce(
         ( select $charged from cust_bill
           where cust_bill._date <= extract(epoch from now())-7776000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_90_plus,

       coalesce(
         ( select $charged from cust_bill
           where cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_total
END

  my $sql = <<END;

select *, $owed_cols from cust_main
where 0 <
  coalesce(
           ( select $charged from cust_bill
             where cust_main.custnum = cust_bill.custnum
           )
           ,0
         )

order by company, last

END

  my $total_sql = "select $owed_cols";

  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;

  my $total_sth = dbh->prepare($total_sql) or die dbh->errstr;
  $total_sth->execute or die $total_sth->errstr;

%>
<%= header('Accounts Receivable Aging Summary', menubar( 'Main Menu'=>$p, ) ) %>
<%= table() %>
  <TR>
    <TH>Customer</TH>
    <TH>0-30</TH>
    <TH>30-60</TH>
    <TH>60-90</TH>
    <TH>90+</TH>
    <TH>Total</TH>
  </TR>
<% while ( my $row = $sth->fetchrow_hashref() ) { %>
  <TR>
    <TD><A HREF="<%= $p %>view/cust_main.cgi?<%= $row->{'custnum'} %>">
        <%= $row->{'company'} ? $row->{'company'}. ' (' : '' %><%= $row->{'last'}. ', '. $row->{'first'} %><%= $row->{'company'} ? ')' : '' %></A>
    </TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_0_30'} ) %></TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_30_60'} ) %></TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_60_90'} ) %></TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_90_plus'} ) %></TD>
    <TD ALIGN="right"><B>$<%= sprintf("%.2f", $row->{'owed_total'} ) %></B></TD>
  </TR>
<% } %>
<% my $row = $total_sth->fetchrow_hashref(); %>
  <TR>
    <TD COLSPAN=6>&nbsp;</TD>
  </TR>
  <TR>
    <TD><I>Total</I></TD>
    <TD ALIGN="right"><I>$<%= sprintf("%.2f", $row->{'owed_0_30'} ) %></TD>
    <TD ALIGN="right"><I>$<%= sprintf("%.2f", $row->{'owed_30_60'} ) %></TD>
    <TD ALIGN="right"><I>$<%= sprintf("%.2f", $row->{'owed_60_90'} ) %></TD>
    <TD ALIGN="right"><I>$<%= sprintf("%.2f", $row->{'owed_90_plus'} ) %></TD>
    <TD ALIGN="right"><I><B>$<%= sprintf("%.2f", $row->{'owed_total'} ) %></B></I></TD>
  </TR>
</TABLE>
</BODY>
</HTML>
