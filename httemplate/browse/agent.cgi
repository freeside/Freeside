<!-- mason kludge -->

<%

  #bad false laziness with search/cust_main.cgi (also needs fixing up for
  #old mysql)
  my $ncancelled = "
     0 < ( SELECT COUNT(*) FROM cust_pkg
                  WHERE cust_pkg.custnum = cust_main.custnum
                    AND ( cust_pkg.cancel IS NULL
                          OR cust_pkg.cancel = 0
                        )
              )
       OR 0 = ( SELECT COUNT(*) FROM cust_pkg
                  WHERE cust_pkg.custnum = cust_main.custnum
              )
  ";

  my $ncancelled_sth = dbh->prepare("SELECT COUNT(*) FROM cust_main
                                       WHERE agentnum = ?
                                         AND ( $ncancelled )         ")
    or die dbh->errstr;

  my $total_sth = dbh->prepare("SELECT COUNT(*) FROM cust_main
                                  WHERE agentnum = ?           ")
    or die dbh->errstr;

%>

<%= header('Agent Listing', menubar(
  'Main Menu'   => $p,
  'Agent Types' => $p. 'browse/agent_type.cgi',
#  'Add new agent' => '../edit/agent.cgi'
)) %>
Agents are resellers of your service. Agents may be limited to a subset of your
full offerings (via their type).<BR><BR>
<A HREF="<%= $p %>edit/agent.cgi"><I>Add a new agent</I></A><BR><BR>

<%= table() %>
<TR>
  <TH COLSPAN=2>Agent</TH>
  <TH>Type</TH>
  <TH>Customers</TH>
  <TH><FONT SIZE=-1>Freq.</FONT></TH>
  <TH><FONT SIZE=-1>Prog.</FONT></TH>
</TR>
<% 
#        <TH><FONT SIZE=-1>Agent #</FONT></TH>
#        <TH>Agent</TH>

foreach my $agent ( sort { 
  #$a->getfield('agentnum') <=> $b->getfield('agentnum')
  $a->getfield('agent') cmp $b->getfield('agent')
} qsearch('agent',{}) ) {

  $ncancelled_sth->execute($agent->agentnum) or die $ncancelled_sth->errstr;
  my $num_ncancelled = $ncancelled_sth->fetchrow_arrayref->[0];

  $total_sth->execute($agent->agentnum) or die $total_sth->errstr;
  my $num_total = $total_sth->fetchrow_arrayref->[0];

  my $num_cancelled = $num_total - $num_ncancelled;

%>

      <TR>
        <TD><A HREF="<%=$p%>edit/agent.cgi?<%= $agent->agentnum %>">
          <%= $agent->agentnum %></A></TD>
        <TD><A HREF="<%=$p%>edit/agent.cgi?<%= $agent->agentnum %>">
          <%= $agent->agent %></A></TD>
        <TD><A HREF="<%=$p%>edit/agent_type.cgi?<%= $agent->typenum %>"><%= $agent->agent_type->atype %></A></TD>
        <TD>
          <FONT COLOR="#00CC00"><B><%= $num_ncancelled %></B></FONT>
            active
          <BR><FONT COLOR="#FF0000"><B><%= $num_cancelled %></B></FONT>
            cancelled
        </TD>
        <TD><%= $agent->freq %></TD>
        <TD><%= $agent->prog %></TD>
      </TR>

<% } %>

    </TABLE>
  </BODY>
</HTML>
