<% include("/elements/header.html","$action Agent", menubar(
  'View all agents' => $p. 'browse/agent.cgi',
)) %>

<% include('/elements/error.html') %>

<FORM METHOD   = POST
      ACTION   = "<%popurl(1)%>process/agent.cgi"
      onSubmit = "return check_agent_custnum_search(this)"
>

<SCRIPT TYPE="text/javascript">
  function check_agent_custnum_search(what) {
    while ( agent_custnum_search_active ) {
      // javascript needs ambien
    }
    return true;
  }
</SCRIPT>

<INPUT TYPE="hidden" NAME="agentnum" VALUE="<% $agent->agentnum %>">
Agent #<% $agent->agentnum ? $agent->agentnum : "(NEW)" %>

<% &ntable("#cccccc", 2, '') %>

  <TR>
    <TH ALIGN="right">Agent</TH>
    <TD><INPUT TYPE="text" NAME="agent" SIZE=32 VALUE="<% $agent->agent %>"></TD>
  </TR>

  <TR>
    <TH ALIGN="right">Agent type</TH>
    <TD>
      <SELECT NAME="typenum" SIZE=1>
%       foreach my $agent_type (qsearch('agent_type',{})) { 

          <OPTION VALUE="<% $agent_type->typenum %>"<% ( $agent->typenum && ( $agent->typenum == $agent_type->typenum ) ) ? ' SELECTED' : '' %>>
    <% $agent_type->getfield('typenum') %>: <% $agent_type->getfield('atype') %>
%       } 
  
      </SELECT>
    </TD>
  </TR>

  <TR>
    <TH ALIGN="right">Master customer</TH>
    <TD>
      <% include('/elements/search-cust_main.html',
                   'field_name'  => 'agent_custnum',
                   'curr_value'  => $agent->agent_custnum,
                   'find_button' => 1,
                )
      %>
    </TD>
  </TR>

% if ( $conf->exists('selfservice-agent_login') ) {

    <TR>
      <TH ALIGN="right">Username</TH>
      <TD><INPUT TYPE="text" NAME="username" SIZE=16 VALUE="<% $agent->username %>"></TD>
    </TR>

    <TR>
      <TH ALIGN="right">Password</TH>
      <TD><INPUT TYPE="password" NAME="_password" SIZE=16 VALUE="<% $agent->_password %>"></TD>
    </TR>

% } else {

    <INPUT TYPE="hidden" NAME="username" VALUE="<% $agent->username |h %>">
    <INPUT TYPE="hidden" NAME="_password" VALUE="<% $agent->_password |h %>">

% }

  <TR>
    <TD ALIGN="right">Disable</TD>
    <TD><INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<% $agent->disabled eq 'Y' ? ' CHECKED' : '' %>></TD>
  </TR>

% if ( $conf->exists('agent-invoice_template') ) {

  <% include('/elements/tr-select-invoice_template.html',
               'label'      => 'Invoice template',
               'field'      => 'invoice_template',
               'curr_value' => $agent->invoice_template,
            )
  %>

% } else {

  <INPUT TYPE="hidden" NAME="invoice_template" VALUE="<% $agent->invoice_template %>">

% }

% if ( $conf->config('ticket_system') ) {
%    my $default_queueid = $conf->config('ticket_system-default_queueid');
%    my $default_queue = FS::TicketSystem->queue($default_queueid);
%    $default_queue = "(default) $default_queueid: $default_queue"
%      if $default_queueid;
%    my %queues = FS::TicketSystem->queues();
%    my @queueids = sort { $a <=> $b } keys %queues;
%  

    <TR>
      <TD ALIGN="right">Ticketing queue</TD>
      <TD>
        <SELECT NAME="ticketing_queueid">
          <OPTION VALUE=""><% $default_queue %>
% foreach my $queueid ( @queueids ) { 

            <OPTION VALUE="<% $queueid %>" <% $agent->ticketing_queueid == $queueid ? ' SELECTED' : '' %>><% $queueid %>: <% $queues{$queueid} %>
% } 

        </SELECT>
      </TD>
    </TR>
% } 

  <TR>
    <TD ALIGN="right">Access Groups</TD>
    <TD><% include('/elements/checkboxes-table.html',
                     'source_obj'   => $agent,
                     'link_table'   => 'access_groupagent',
                     'target_table' => 'access_group',
                     'name_col'     => 'groupname',
                     'target_link'  => $p. 'edit/access_group.html?',
                  )
        %>
    </TD>
  </TR>

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="<% $agent->agentnum ? "Apply changes" : "Add agent" %>">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $agent;
if ( $cgi->param('error') ) {
  $agent = new FS::agent ( {
    map { $_, scalar($cgi->param($_)) } fields('agent')
  } );
} elsif ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $agent = qsearchs( 'agent', { 'agentnum' => $1 } );
} else { #adding
  $agent = new FS::agent {};
}
my $action = $agent->agentnum ? 'Edit' : 'Add';

my $conf = new FS::Conf;

</%init>
