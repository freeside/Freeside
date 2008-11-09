<% include("/elements/header.html",'Agent Listing', menubar(
  'Agent Types' => $p. 'browse/agent_type.cgi',
#  'Add new agent' => '../edit/agent.cgi'
)) %>
Agents are resellers of your service. Agents may be limited to a subset of your
full offerings (via their type).<BR><BR>
<A HREF="<% $p %>edit/agent.cgi"><I>Add a new agent</I></A><BR><BR>
% if ( dbdef->table('agent')->column('disabled') ) { 

  <% $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled agents</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled agents</a> )'; }
  %>
% } 


<% include('/elements/table-grid.html') %>
% my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor = '';
%


<TR>
  <TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=<% ( $cgi->param('showdisabled') || !dbdef->table('agent')->column('disabled') ) ? 2 : 3 %>>Agent</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Type</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Master Customer</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Invoice<BR>Template</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Customers</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Customer<BR>packages</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Reports</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Registration<BR>codes</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Prepaid cards</TH>
% if ( $conf->config('ticket_system') ) { 

    <TH CLASS="grid" BGCOLOR="#cccccc">Ticketing</TH>
% } 

  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Payment Gateway Overrides</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Configuration Overrides</FONT></TH>
</TR>
% 
%#        <TH><FONT SIZE=-1>Agent #</FONT></TH>
%#        <TH>Agent</TH>
%
%foreach my $agent ( sort { 
%  #$a->getfield('agentnum') <=> $b->getfield('agentnum')
%  $a->getfield('agent') cmp $b->getfield('agent')
%} qsearch('agent', \%search ) ) {
%
%  my $cust_main_link = $p. 'search/cust_main.cgi?agentnum_on=1&'.
%                       'agentnum='. $agent->agentnum;
%
%  my $cust_pkg_link = $p. 'search/cust_pkg.cgi?agentnum='. $agent->agentnum;
%  
%  if ( $bgcolor eq $bgcolor1 ) {
%    $bgcolor = $bgcolor2;
%  } else {
%    $bgcolor = $bgcolor1;
%  }
%
%


      <TR>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/agent.cgi?<% $agent->agentnum %>"><% $agent->agentnum %></A>
        </TD>

%       if ( dbdef->table('agent')->column('disabled')
%            && !$cgi->param('showdisabled')           ) { 
          <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
            <% $agent->disabled ? 'DISABLED' : '' %>
          </TD>
%       } 

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/agent.cgi?<% $agent->agentnum %>"><% $agent->agent %></A>
        </TD>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/agent_type.cgi?<% $agent->typenum %>"><% $agent->agent_type->atype %></A>
        </TD>

        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
%         if ( $agent->agent_custnum ) {
            <% include('/elements/small_custview.html',
                         $agent->agent_custnum,
                         scalar($conf->config('countrydefault')),
                         1, #show balance
                      )
            %>
%         }
        </TD>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $agent->invoice_template || '(Default)' %>
        </TD>

        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>" VALIGN="bottom">
          <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#7e0079">
                  <% my $num_prospect = $agent->num_prospect_cust_main %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_prospect ) { 

                  <A HREF="<% $cust_main_link %>&prospect=1">
% } 
prospects
% if ($num_prospect ) { 
</A>
% } 

              <TD>
            </TR>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#0000CC">
                  <% my $num_inactive = $agent->num_inactive_cust_main %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_inactive ) { 

                  <A HREF="<% $cust_main_link %>&inactive=1">
% } 
inactive
% if ( $num_inactive ) { 
</A>
% } 

              </TD>
            </TR>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#00CC00">
                  <% my $num_active = $agent->num_active_cust_main %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_active ) { 

                  <A HREF="<% $cust_main_link %>&active=1">
% } 
active
% if ( $num_active ) { 
</A>
% } 

              </TD>
            </TR>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#FF9900">
                  <% my $num_susp = $agent->num_susp_cust_main %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_susp ) { 

                  <A HREF="<% $cust_main_link %>&suspended=1">
% } 
suspended
% if ( $num_susp ) { 
</A>
% } 

              </TD>
            </TR>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#FF0000">
                  <% my $num_cancel = $agent->num_cancel_cust_main %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_cancel ) { 

                  <A HREF="<% $cust_main_link %>&showcancelledcustomers=1&cancelled=1">
% } 
cancelled
% if ( $num_cancel ) { 
</A>
% } 

              </TD>
            </TR>

          </TABLE>
        </TD>

        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>" VALIGN="bottom">
          <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#0000CC">
                  <% my $num_inactive_pkg = $agent->num_inactive_cust_pkg %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_inactive_pkg ) { 

                  <A HREF="<% $cust_pkg_link %>&magic=inactive">
% } 
inactive
% if ( $num_inactive_pkg ) { 
</A>
% } 

              </TD>
            </TR>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#00CC00">
                  <% my $num_active_pkg = $agent->num_active_cust_pkg %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_active_pkg ) { 

                  <A HREF="<% $cust_pkg_link %>&magic=active">
% } 
active
% if ( $num_active_pkg ) { 
</A>
% } 

              </TD>
            </TR>

            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#FF9900">
                  <% my $num_susp_pkg = $agent->num_susp_cust_pkg %>&nbsp;
                </FONT>

              </TH>
              <TD>
% if ( $num_susp_pkg ) { 

                  <A HREF="<% $cust_pkg_link %>&magic=suspended">
% } 
suspended
% if ( $num_susp_pkg ) { 
</A>
% } 

              </TD>
            </TR>
            
            <TR>
              <TH ALIGN="right" WIDTH="40%">
                <FONT COLOR="#FF0000">
                  <% my $num_cancel_pkg = $agent->num_cancel_cust_pkg %>&nbsp;
                </FONT>
              </TH>

              <TD>
% if ( $num_cancel_pkg ) { 

                  <A HREF="<% $cust_pkg_link %>&magic=cancelled">
% } 
cancelled
% if ( $num_cancel_pkg ) { 
</A>
% } 

              </TD>
            </TR>

          </TABLE>
        </TD>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<% $p %>graph/report_cust_pkg.html?agentnum=<% $agent->agentnum %>">Package&nbsp;Churn</A>
          <BR><A HREF="<% $p %>search/report_cust_pay.html?agentnum=<% $agent->agentnum %>">Payments</A>
          <BR><A HREF="<% $p %>search/report_cust_credit.html?agentnum=<% $agent->agentnum %>">Credits</A>
          <BR><A HREF="<% $p %>search/report_receivables.cgi?agentnum=<% $agent->agentnum %>">A/R&nbsp;Aging</A>
          <!--<BR><A HREF="<% $p %>search/money_time.cgi?agentnum=<% $agent->agentnum %>">Sales/Credits/Receipts</A>-->

        </TD>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% my $num_reg_code = $agent->num_reg_code %>
% if ( $num_reg_code ) { 

            <A HREF="<%$p%>search/reg_code.html?agentnum=<% $agent->agentnum %>">
% } 
Unused
% if ( $num_reg_code ) { 
</A>
% } 

          <BR><A HREF="<%$p%>edit/reg_code.cgi?agentnum=<% $agent->agentnum %>">Generate codes</A>
        </TD>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% my $num_prepay_credit = $agent->num_prepay_credit %>
% if ( $num_prepay_credit ) { 

            <A HREF="<%$p%>search/prepay_credit.html?agentnum=<% $agent->agentnum %>">
% } 
Unused
% if ( $num_prepay_credit ) { 
</A>
% } 

          <BR><A HREF="<%$p%>edit/prepay_credit.cgi?agentnum=<% $agent->agentnum %>">Generate cards</A>
        </TD>
% if ( $conf->config('ticket_system') ) { 


          <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
% if ( $agent->ticketing_queueid ) { 

              Queue: <% $agent->ticketing_queueid %>: <% $agent->ticketing_queue %><BR>
% } 

          </TD>
% } 


        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
          <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>
% foreach my $override (
%                 # sort { }  want taxclass-full stuff first?  and default cards (empty cardtype)
%                 qsearch('agent_payment_gateway', { 'agentnum' => $agent->agentnum } )
%               ) {
%            

              <TR>
                <TD> 
                  <% $override->cardtype || 'Default' %> to <% $override->payment_gateway->gateway_module %> (<% $override->payment_gateway->gateway_username %>)
                  <% $override->taxclass
                        ? ' for '. $override->taxclass. ' only'
                        : ''
                  %>
                  <FONT SIZE=-1><A HREF="<%$p%>misc/delete-agent_payment_gateway.cgi?<% $override->agentgatewaynum %>">(delete)</A></FONT>
                </TD>
              </TR>
% } 

            <TR>
              <TD><FONT SIZE=-1><A HREF="<%$p%>edit/agent_payment_gateway.html?agentnum=<% $agent->agentnum %>">(add override)</A></FONT></TD>
            </TR>
          </TABLE>
        </TD>

        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
          <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>
% foreach my $override (
%                 qsearch('conf', { 'agentnum' => $agent->agentnum } )
%               ) {
%            

              <TR>
                <TD> 
                  <% $override->name %>
                  <FONT SIZE=-1><A HREF="<%$p%>config/config-delete.cgi?<% $override->confnum %>">(delete)</A></FONT>
                </TD>
              </TR>
% } 

            <TR>
              <TD><FONT SIZE=-1><A HREF="<%$p%>config/config-view.cgi?agentnum=<% $agent->agentnum %>">(add override)</A></FONT></TD>
            </TR>
          </TABLE>
        </TD>

      </TR>
% } 


    </TABLE>
  </BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my %search;
if ( $cgi->param('showdisabled')
     || !dbdef->table('agent')->column('disabled') ) {
  %search = ();
} else {
  %search = ( 'disabled' => '' );
}

my $conf = new FS::Conf;

</%init>
