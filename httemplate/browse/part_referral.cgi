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
  my %after;
  tie %after, 'Tie::IxHash',
    'Today'         =>        0,
    'Yesterday'     =>    86400, # 60sec * 60min * 24hrs
    'Past week'     =>   518400, # 60sec * 60min * 24hrs * 6days
    'Past 30 days'  =>  2505600, # 60sec * 60min * 24hrs * 29days 
    'Past 60 days'  =>  5097600, # 60sec * 60min * 24hrs * 59days 
    'Past 90 days'  =>  7689600, # 60sec * 60min * 24hrs * 89days 
    'Past 6 months' => 15724800, # 60sec * 60min * 24hrs * 182days 
    'Past year'     => 31486000, # 60sec * 60min * 24hrs * 364days 
    'Total'         => $today,
  ;
  my %before = (
    'Today'         =>   86400, # 60sec * 60min * 24hrs
    'Yesterday'     =>       0,
    'Past week'     =>   86400, # 60sec * 60min * 24hrs
    'Past 30 days'  =>   86400, # 60sec * 60min * 24hrs
    'Past 60 days'  =>   86400, # 60sec * 60min * 24hrs
    'Past 90 days'  =>   86400, # 60sec * 60min * 24hrs
    'Past 6 months' =>   86400, # 60sec * 60min * 24hrs
    'Past year'     =>   86400, # 60sec * 60min * 24hrs
    'Total'         =>   86400, # 60sec * 60min * 24hrs
  );

  my $statement = "SELECT COUNT(*) FROM h_cust_main
                    WHERE history_action = 'insert'
                      AND refnum = ?
                      AND history_date >= ?
		      AND history_date < ?
		  ";
  my $sth = dbh->prepare($statement)
    or die dbh->errstr;
%>

<%= table() %>
<TR>
  <TH COLSPAN=2 ROWSPAN=2>Advertising source</TH>
  <TH COLSPAN=<%= scalar(keys %after) %>>Customers</TH>
</TR>
<% for my $period ( keys %after ) { %>
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
        <% for my $period ( keys %after ) {
          $sth->execute( $part_referral->refnum,
                         $today-$after{$period},
                         $today+$before{$period},
          ) or die $sth->errstr;
          my $number = $sth->fetchrow_arrayref->[0];
        %>
          <TD ALIGN="right"><%= $number %></TD>
        <% } %>
      </TR>
<% } %>

<%
  $statement =~ s/AND refnum = \?//;
  $sth = dbh->prepare($statement)
    or die dbh->errstr;
%>
      <TR>
        <TH COLSPAN=2>Total</TH>
        <% for my $period ( keys %after ) {
          $sth->execute( $today-$after{$period},
                         $today+$before{$period},
          ) or die $sth->errstr;
          my $number = $sth->fetchrow_arrayref->[0];
        %>
          <TD ALIGN="right"><%= $number %></TD>
        <% } %>
      </TR>
        <TD></TD>
    </TABLE>
  </BODY>
</HTML>
