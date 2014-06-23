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

<TR>
  <TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=<% ( $cgi->param('showdisabled') || !dbdef->table('agent')->column('disabled') ) ? 2 : 3 %>>Agent</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Type</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Master Customer</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Commissions</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Access Groups</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Invoice<BR>Template</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Customers</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Customer<BR>packages</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Reports</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Registration<BR>codes</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Prepaid cards</TH>

% if ( $conf->config('ticket_system') ) { 
    <TH CLASS="grid" BGCOLOR="#cccccc">Ticketing</TH>
% } 

% if ( $conf->config('currencies') ) { 
    <TH CLASS="grid" BGCOLOR="#cccccc">Currencies</TH>
% } 

  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Payment Gateway Overrides</FONT></TH>
  <TH CLASS="grid" BGCOLOR="#cccccc"><FONT SIZE=-1>Configuration Overrides</FONT></TH>
</TR>

%#        <TH><FONT SIZE=-1>Agent #</FONT></TH>
%#        <TH>Agent</TH>
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

      <TR>

%       ##
%       # agentnum
%       ##
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/agent.cgi?<% $agent->agentnum %>"><% $agent->agentnum %></A>
        </TD>

%       ##
%       # disabled
%       ##
%       if ( ! $cgi->param('showdisabled') ) { 
          <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ALIGN="center">
            <% $agent->disabled ? '<FONT COLOR="#FF0000"><B>DISABLED</B></FONT>'
                                : '<FONT COLOR="#00CC00"><B>Active</B></FONT>'
            %>
          </TD>
%       } 

%       ##
%       # agent
%       ##
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/agent.cgi?<% $agent->agentnum %>"><% $agent->agent %></A>
        </TD>

%       ##
%       # type
%       ##
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/agent_type.cgi?<% $agent->typenum %>"><% $agent->agent_type->atype %></A>
        </TD>

%       ##
%       # master customer
%       ##
        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
%         if ( $agent->agent_custnum ) {
            <& /elements/small_custview.html,
                 $agent->agent_custnum,
                 scalar($conf->config('countrydefault')),
                 1, #show balance
                 $p.'view/cust_main.cgi',
            &>
%         }
        </TD>

%       ##
%       # commissions
%       ##

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">

          <TABLE>

%           #surprising amount of false laziness w/ edit/process/agent.cgi
%           my @pkg_class = qsearch('pkg_class', { 'disabled'=>'' });
%           foreach my $pkg_class ( '', @pkg_class ) {
%             my %agent_pkg_class = ( 'agentnum' => $agent->agentnum,
%                                     'classnum' => $pkg_class ? $pkg_class->classnum : ''
%                                   );
%             my $agent_pkg_class =
%               qsearchs( 'agent_pkg_class', \%agent_pkg_class )
%               || new FS::agent_pkg_class   \%agent_pkg_class;
%             my $param = 'classnum'. $agent_pkg_class{classnum};

              <TR>
                <TD><% $agent_pkg_class->commission_percent || 0 %>%</TD>
                <TD><% $pkg_class ? $pkg_class->classname : mt('(no package class)') |h %>
                </TD>
              </TR>

%           }

          </TABLE>

        </TD>

%       ##
%       # access groups
%       ##
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
%         foreach my $access_group (
%           map $_->access_group,
%               qsearch('access_groupagent', { 'agentnum' => $agent->agentnum })
%         ) {
            <A HREF="<%$p%>edit/access_group.html?<% $access_group->groupnum %>"><% $access_group->groupname |h %><BR>
%         }
        </TD>

%       ##
%       # invoice template
%       ##
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $agent->invoice_template || '(Default)' %>
        </TD>

%       ##
%       # customers
%       ##

        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>" VALIGN="bottom">
          <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>

%           my @cust_status =
%             qw( prospect inactive ordered active suspended cancelled );
%           my %method = ( 'suspended' => 'susp',
%                          'cancelled' => 'cancel'
%                        );
%           my %PL = ( 'prospect' => 'prospects', );
%           my %link = ( 'cancelled' => 'showcancelledcustomers=1&cancelled' );
%           my $statuscolor = FS::cust_main->statuscolors;
%
%           foreach my $status ( @cust_status ) {
%             my $meth = exists($method{$status}) ? $method{$status} : $status;
%             $meth = 'num_'. $meth. '_cust_main';
%             my $link = exists($link{$status}) ? $link{$status} : $status;

              <TR>
%               my $num = 0;
%               unless ( $disable_counts ) {
                  <TH ALIGN="right" WIDTH="40%">
                    <FONT COLOR="#<% $statuscolor->{$status} %>">
                      <% $num = $agent->$meth() %>&nbsp;
                    </FONT>
                  </TH>
%               }
                <TD>
% if ( $num || $disable_counts ) { 
%                 

                  <A HREF="<% $cust_main_link. "&$link=1" %>">
% } 
<% exists($PL{$status}) ? $PL{$status} : $status %>
% if ($num || $disable_counts ) {
</A>
% } 

              <TD>
            </TR>

%           }

          </TABLE>
        </TD>

%       ##
%       # customer packages
%       ##

        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>" VALIGN="bottom">
          <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>

%           #my @pkg_status = FS::cust_pkg->statuses;
%           my @pkg_status = ( 'on hold', 'one-time charge', 'not yet billed',
%                              qw( active suspended cancelled ) );
%           my %method = ( 'one-time charge' => 'inactive',
%                          'suspended'       => 'susp',
%                          'cancelled'       => 'cancel',
%                        );
%           my $statuscolor = FS::cust_pkg->statuscolors;
%
%           foreach my $status ( @pkg_status ) {
%             my $magic = exists($method{$status}) ? $method{$status} : $status;
%             $magic =~ s/ /_/g;
%             my $meth = 'num_'. $magic. '_cust_pkg';
%             ( my $label = $status ) =~ s/ /&nbsp;/g;

              <TR>
%               my $num = 0;
%               unless ( $disable_counts ) {
                  <TH ALIGN="right" WIDTH="40%">
                    <FONT COLOR="#<% $statuscolor->{$status} %>">
                      <% $num = $agent->$meth() %>&nbsp;
                    </FONT>
                  </TH>
%               }

              <TD>
% if ( $num || $disable_counts ) { 

                  <A HREF="<% $cust_pkg_link %>&magic=<% $magic %>">
% } 
<% $label %>
% if ( $num || $disable_counts ) { 
</A>
% } 

              </TD>
            </TR>

%           }

          </TABLE>
        </TD>

%       ##
%       # reports
%       ##
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<% $p %>graph/report_cust_pkg.html?agentnum=<% $agent->agentnum %>">Package&nbsp;Churn</A>
          <BR><A HREF="<% $p %>search/report_cust_pay.html?agentnum=<% $agent->agentnum %>">Payments</A>
          <BR><A HREF="<% $p %>search/report_cust_credit.html?agentnum=<% $agent->agentnum %>">Credits</A>
          <BR><A HREF="<% $p %>search/report_receivables.cgi?agentnum=<% $agent->agentnum %>">A/R&nbsp;Aging</A>
          <!--<BR><A HREF="<% $p %>search/money_time.cgi?agentnum=<% $agent->agentnum %>">Sales/Credits/Receipts</A>-->
        </TD>

%       ##
%       # registration codes
%       ##

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

%       ##
%       # prepaid cards
%       ##

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

%       ##
%       # ticketing
%       ##
% if ( $conf->config('ticket_system') ) { 
          <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
%         if ( $agent->ticketing_queueid ) { 
              Queue: <% $agent->ticketing_queueid %>:
                     <% $agent->ticketing_queue %>
              <BR>
%         } 
          </TD>
% } 

%       ##
%       # currencies
%       ##
% if ( $conf->config('currencies') ) { 
          <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
            <% join('<BR>', sort keys %{ $agent->agent_currency_hashref } ) %>
          </TD>
% } 

%       ##
%       # payment gateway overrides
%       ##

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
                  <FONT SIZE=-1><A HREF="javascript:areyousure('delete this payment gateway override', '<%$p%>misc/delete-agent_payment_gateway.cgi?<% $override->agentgatewaynum %>')">(delete)</A></FONT>
                </TD>
              </TR>
% } 

            <TR>
              <TD><FONT SIZE=-1><A HREF="<%$p%>edit/agent_payment_gateway.html?agentnum=<% $agent->agentnum %>">(add override)</A></FONT></TD>
            </TR>
          </TABLE>
        </TD>

%       ##
%       # configuration overrides
%       ##

        <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
          <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>
% foreach my $override (
%                 qsearch('conf', { 'agentnum' => $agent->agentnum } )
%               ) {
%            

              <TR>
                <TD> 
                  <% $override->name %>&nbsp;<FONT SIZE=-1><A HREF="javascript:areyousure('delete this configuration override', '<%$p%>config/config-delete.cgi?confnum=<% $override->confnum %>')">(delete)</A></FONT>
                </TD>
              </TR>
% } 

            <TR>
              <TD><FONT SIZE=-1><A HREF="<%$p%>config/config-view.cgi?agentnum=<% $agent->agentnum %>">(view/add/edit overrides)</A></FONT></TD>
            </TR>
          </TABLE>
        </TD>

      </TR>
% } 


    </TABLE>

<SCRIPT TYPE="text/javascript">
  function areyousure(what, href) {
    if ( confirm("Are you sure you want to " + what + "?") == true )
      window.location.href = href;
  }
</SCRIPT>

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
my $disable_counts = $conf->exists('agent-disable_counts');

</%init>
