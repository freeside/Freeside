<!-- mason kludge -->
<%= header("Advertising source Listing", menubar(
  'Main Menu' => $p,
#  'Add new referral' => "../edit/part_referral.cgi",
)) %>
Where a customer heard about your service. Tracked for informational purposes.
<BR><BR>
<A HREF="<%= $p %>edit/part_referral.cgi"><I>Add a new advertising source</I></A>
<BR><BR>

<%
  my $today = timelocal(0, 0, 0, (localtime(time))[3..5] );
  my %past;
  tie %past, 'Tie::IxHash',
    'Today'         =>        0,
    'Past week'     =>   518400, # 60sec * 60min * 24hrs * 6days
    'Past 30 days'  =>  2505600, # 60sec * 60min * 24hrs * 29days 
    'Past 60 days'  =>  5097600, # 60sec * 60min * 24hrs * 29days 
    'Past 90 days'  =>  7689600, # 60sec * 60min * 24hrs * 29days 
    'Past 6 months' => 15724800, # 60sec * 60min * 24hrs * 182days 
    'Past year'     => 31486000, # 60sec * 60min * 24hrs * 364days 
    'Total'         => $today,
  ;

  my $sth = dbh->prepare("SELECT COUNT(*) FROM h_cust_main
                            WHERE history_action = 'insert'
                              AND refnum = ?
                              AND history_date > ?         ")
    or die dbh->errstr;
%>

<%= table() %>
<TR>
  <TH COLSPAN=2 ROWSPAN=2>Advertising source</TH>
  <TH COLSPAN=<%= scalar(keys %past) %>>Customers</TH>
</TR>
<% for my $period ( keys %past ) { %>
  <TH><FONT SIZE=-1><%= $period %></FONT></TH>
<% } %>
</TR>

<%
foreach my $part_referral ( sort { 
  $a->getfield('refnum') <=> $b->getfield('refnum')
} qsearch('part_referral',{}) ) {
%>
      <TR>
        <TD><A HREF="<%= $p %>edit/part_referral.cgi?<%= $part_referral->refnum %>">
          <%= $part_referral->refnum %></A></TD>
        <TD><A HREF="<%= $p %>edit/part_referral.cgi?<%= $part_referral->refnum %>">
          <%= $part_referral->referral %></A></TD>
        <% for my $period ( values %past ) {
          $sth->execute($part_referral->refnum, $today-$period)
            or die $sth->errstr;
          my $number = $sth->fetchrow_arrayref->[0];
        %>
          <TD ALIGN="right"><%= $number %></TD>
        <% } %>
      </TR>
<% } %>

    </TABLE>
  </BODY>
</HTML>
