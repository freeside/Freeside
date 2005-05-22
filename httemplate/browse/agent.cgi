<%

  my %search;
  if ( $cgi->param('showdisabled')
       || !dbdef->table('agent')->column('disabled') ) {
    %search = ();
  } else {
    %search = ( 'disabled' => '' );
  }

%>
<%= header('Agent Listing', menubar(
  'Main Menu'   => $p,
  'Agent Types' => $p. 'browse/agent_type.cgi',
#  'Add new agent' => '../edit/agent.cgi'
)) %>
Agents are resellers of your service. Agents may be limited to a subset of your
full offerings (via their type).<BR><BR>
<A HREF="<%= $p %>edit/agent.cgi"><I>Add a new agent</I></A><BR><BR>

<% if ( dbdef->table('agent')->column('disabled') ) { %>
  <%= $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled agents</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled agents</a> )'; }
  %>
<% } %>

<%= table() %>
<TR>
  <TH COLSPAN=<%= ( $cgi->param('showdisabled') || !dbdef->table('agent')->column('disabled') ) ? 2 : 3 %>>Agent</TH>
  <TH>Type</TH>
  <TH>Customers</TH>
  <TH>Reports</TH>
  <TH>Registration codes</TH>
  <TH>Prepaid cards</TH>
  <TH><FONT SIZE=-1>Freq.</FONT></TH>
  <TH><FONT SIZE=-1>Prog.</FONT></TH>
</TR>
<% 
#        <TH><FONT SIZE=-1>Agent #</FONT></TH>
#        <TH>Agent</TH>

foreach my $agent ( sort { 
  #$a->getfield('agentnum') <=> $b->getfield('agentnum')
  $a->getfield('agent') cmp $b->getfield('agent')
} qsearch('agent', \%search ) ) {

  my $cust_main_link = $p. 'search/cust_main.cgi?agentnum_on=1&'.
                       'agentnum='. $agent->agentnum;

%>

      <TR>
        <TD><A HREF="<%=$p%>edit/agent.cgi?<%= $agent->agentnum %>">
          <%= $agent->agentnum %></A></TD>
<% if ( dbdef->table('agent')->column('disabled')
        && !$cgi->param('showdisabled')           ) { %>
        <TD><%= $agent->disabled ? 'DISABLED' : '' %></TD>
<% } %>

        <TD><A HREF="<%=$p%>edit/agent.cgi?<%= $agent->agentnum %>">
          <%= $agent->agent %></A></TD>
        <TD><A HREF="<%=$p%>edit/agent_type.cgi?<%= $agent->typenum %>"><%= $agent->agent_type->atype %></A></TD>

        <TD>

          <TABLE CELLSPACING=0 CELLPADDING=0>
            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <%= my $num_prospect = $agent->num_prospect_cust_main %>&nbsp;
              </TH>
              <TD>
                <% if ( $num_prospect ) { %>
                  <A HREF="<%= $cust_main_link %>&prospect=1"><% } %>prospects<% if ($num_prospect ) { %></A><% } %>
              <TD>
            </TR>
            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#00CC00">
                  <%= my $num_active = $agent->num_active_cust_main %>&nbsp;
                </FONT>
              </TH>
              <TD>
                <% if ( $num_active ) { %>
                  <A HREF="<%= $cust_main_link %>&active=1"><% } %>active<% if ( $num_active ) { %></A><% } %>
              </TD>
            </TR>
            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#FF9900">
                  <%= my $num_susp = $agent->num_susp_cust_main %>&nbsp;
                </FONT>
              </TH>
              <TD>
                <% if ( $num_susp ) { %>
                  <A HREF="<%= $cust_main_link %>&suspended=1"><% } %>suspended<% if ( $num_susp ) { %></A><% } %>
              </TD>
            </TR>
            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#FF0000">
                  <%= my $num_cancel = $agent->num_cancel_cust_main %>&nbsp;
                </FONT>
              </TH>
              <TD>
                <% if ( $num_cancel ) { %>
                  <A HREF="<%= $cust_main_link %>&showcancelledcustomers=1&cancelled=1"><% } %>cancelled<% if ( $num_cancel ) { %></A><% } %>
              </TD>
            </TR>
          </TABLE>
        </TD>

        <TD>
          <A HREF="<%= $p %>search/report_cust_pay.html?agentnum=<%= $agent->agentnum %>">Payments</A>
          <BR><A HREF="<%= $p %>search/report_cust_credit.html?agentnum=<%= $agent->agentnum %>">Credits</A>
          <BR><A HREF="<%= $p %>search/report_receivables.cgi?agentnum=<%= $agent->agentnum %>">A/R Aging</A>
          <!--<BR><A HREF="<%= $p %>search/money_time.cgi?agentnum=<%= $agent->agentnum %>">Sales/Credits/Receipts</A>-->

        </TD>

        <TD>
          <%= my $num_reg_code = $agent->num_reg_code %>
          <% if ( $num_reg_code ) { %>
            <A HREF="<%=$p%>search/reg_code.html?agentnum=<%= $agent->agentnum %>"><% } %>Unused<% if ( $num_reg_code ) { %></A><% } %>
          <BR><A HREF="<%=$p%>edit/reg_code.cgi?agentnum=<%= $agent->agentnum %>">Generate codes</A>
        </TD>

        <TD>
          <%= my $num_prepay_credit = $agent->num_prepay_credit %>
          <% if ( $num_prepay_credit ) { %>
            <A HREF="<%=$p%>search/prepay_credit.html?agentnum=<%= $agent->agentnum %>"><% } %>Unused<% if ( $num_prepay_credit ) { %></A><% } %>
          <BR><A HREF="<%=$p%>edit/prepay_credit.cgi?agentnum=<%= $agent->agentnum %>">Generate cards</A>
        </TD>

        <TD><%= $agent->freq %></TD>
        <TD><%= $agent->prog %></TD>

      </TR>

<% } %>

    </TABLE>
  </BODY>
</HTML>
