<!-- mason kludge -->
<%
  my $sql = <<END;

select *,

       coalesce(
         ( select sum( charged
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )

                     )
           from cust_bill
           where cust_bill._date > extract(epoch from now())-2592000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_0_30,

       coalesce(
         ( select sum( charged
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )

                     )
           from cust_bill
           where cust_bill._date >  extract(epoch from now())-5184000
             and cust_bill._date <= extract(epoch from now())-2592000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_30_60,

       coalesce(
         ( select sum( charged
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )

                     )
           from cust_bill
           where cust_bill._date >  extract(epoch from now())-7776000
             and cust_bill._date <= extract(epoch from now())-5184000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_60_90,

       coalesce(
         ( select sum( charged
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )

                     )
           from cust_bill
           where cust_bill._date <= extract(epoch from now())-7776000
             and cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_90_plus,

       coalesce(
         ( select sum( charged
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )
                       - coalesce(
                           ( select sum(amount) from cust_bill_pay
                             where cust_bill.invnum = cust_bill_pay.invnum )
                           ,0
                         )

                     )
           from cust_bill
           where cust_main.custnum = cust_bill.custnum
         )
         ,0
       ) as owed_total

from cust_main

where 0 <
  coalesce(
           ( select sum( charged
                         - coalesce(
                             ( select sum(amount) from cust_bill_pay
                               where cust_bill.invnum = cust_bill_pay.invnum )
                             ,0
                           )
                         - coalesce(
                             ( select sum(amount) from cust_bill_pay
                               where cust_bill.invnum = cust_bill_pay.invnum )
                             ,0
                           )
  
                       )
             from cust_bill
             where cust_main.custnum = cust_bill.custnum
           )
           ,0
         )

order by company, last

END


  #order by!

  #the grep (and the sort ) should be pushed down to SQL
  #my @cust_main = sort {    $a->company cmp $b->company 
  #                       || $a->last    cmp $b->last    }
  #                grep { $_->balance }
  #                qsearch('cust_main', {} );

  my $totals_table = table(). '<TR><TH>Total</TH>'.
                             '<TD><i>0-30</i></TD>'.
                             '<TD><i>30-60</i></TD>'.
                             '<TD><i>60-90</i></TD>'.
                             '<TD><i>90+</i></TD>'.
                             '<TD><i>total</i></TD>'.
                             '</TABLE>';
  $totals_table = '';

  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;

%>
<%= header('Accounts Receivable Aging Summary', menubar( 'Main Menu'=>$p, ) ) %>
<%= $totals_table %>
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
    <TD><A HREF="<% $p %>view/cust_main.cgi?<%= $row->{'custnum'} %>">
        <%= $row->{'company'} ? $row->{'company'}. ' (' : '' %>
        <%= $row->{'last'}. ', '. $row->{'first'} %>
        <%= $row->{'company'} ? ')' : '' %></A>
    </TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_0_30'} ) %></TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_30_60'} ) %></TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_60_90'} ) %></TD>
    <TD ALIGN="right">$<%= sprintf("%.2f", $row->{'owed_90_plus'} ) %></TD>
    <TD ALIGN="right"><B>$<%= sprintf("%.2f", $row->{'owed_total'} ) %></B></TD>
  </TR>
<% } %>
</TABLE>
<%= $totals_table %>
</BODY>
</HTML>
