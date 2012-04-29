<% include("/elements/header.html",'Sales Listing', menubar(
  'Add new sales person' => '../edit/sales.cgi'
)) %>
Sales people bring in business.<BR><BR>
% if ( dbdef->table('sales')->column('disabled') ) { 

  <% $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled sales people</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled sales people</a> )'; }
  %>
% } 


<% include('/elements/table-grid.html') %>
% my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor = '';

<TR>
  <TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=<% ( $cgi->param('showdisabled') || !dbdef->table('sales')->column('disabled') ) ? 2 : 3 %>>Sales person</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Agent</TH>
  <TH CLASS="grid" BGCOLOR="#cccccc">Access Groups</TH>
</TR>

%foreach my $sales ( sort { 
%  $a->getfield('salesnum') cmp $b->getfield('salesnum')
%} qsearch('sales', \%search ) ) {
%
%  if ( $bgcolor eq $bgcolor1 ) {
%    $bgcolor = $bgcolor2;
%  } else {
%    $bgcolor = $bgcolor1;
%  }

      <TR>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/sales.cgi?<% $sales->salesnum %>"><% $sales->salesnum %></A>
        </TD>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/sales.cgi?<% $sales->salesnum %>"><% $sales->salesperson %></A>
        </TD>

%       if ( ! $cgi->param('showdisabled') ) { 
          <TD CLASS="grid" BGCOLOR="<% $bgcolor %>" ALIGN="center">
            <% $sales->disabled ? '<FONT COLOR="#FF0000"><B>DISABLED</B></FONT>'
                                : '<FONT COLOR="#00CC00"><B>Active</B></FONT>'
            %>
          </TD>
%       } 

%       my ($agent) = qsearch('agent', { 'agentnum' => $sales->agentnum });

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <A HREF="<%$p%>edit/sales.cgi?<% $sales->agentnum %>"><% $sales->agentnum %></A>
          <A HREF="<%$p%>edit/agent.cgi?<% $agent->agentnum %>">(<% $agent->agent %>)<BR>
        </TD>

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
%         foreach my $access_group (
%           map $_->access_group,
%               qsearch('access_groupsales', { 'salesnum' => $sales->salesnum })
%         ) {
            <A HREF="<%$p%>edit/access_group.html?<% $access_group->groupnum %>"><% $access_group->groupname |h %><BR>
%         }
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

</%init>
