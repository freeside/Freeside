<%
my $agent = '';
my $agentnum = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agent = qsearchs('agent', { 'agentnum' => $agentnum=$1 } );
}

tie my %multiplier, 'Tie::IxHash',
  1    => 'seconds',
  60   => 'minutes',
  3600 => 'hours',
;

$cgi->param('multiplier', '60') unless $cgi->param('multiplier');

%>

<%= header('Generate prepaid cards'. ($agent ? ' for '. $agent->agent : ''),
           menubar( 'Main Menu' => $p, ))
%>

<% if ( $cgi->param('error') ) { %>
  <FONT SIZE="+1" COLOR="#FF0000">Error: <%= $cgi->param('error') %></FONT>
<% } %>

<FORM ACTION="<%=popurl(1)%>process/prepay_credit.cgi" METHOD="POST" NAME="OneTrueForm" onSubmit="document.OneTrueForm.submit.disabled=true">

Generate
<INPUT TYPE="text" NAME="num" VALUE="<%= $cgi->param('num') || '(quantity)' %>" SIZE=10 MAXLENGTH=10 onFocus="if ( this.value == '(quantity)' ) { this.value = ''; }">
<SELECT NAME="type">
<% foreach (qw(alpha alphanumeric numeric)) { %>
  <OPTION<%= $cgi->param('type') eq $_ ? ' SELECTED' : '' %>><%= $_ %>
<% } %>
</SELECT>
 prepaid cards

<BR>for <SELECT NAME="agentnum"><OPTION>(any agent)
<% foreach my $opt_agent ( qsearch('agent', { 'disabled' => '' } ) ) { %>
  <OPTION VALUE="<%= $opt_agent->agentnum %>"<%= $opt_agent->agentnum == $agentnum ? ' SELECTED' : '' %>><%= $opt_agent->agent %>
<% } %>
</SELECT>

<BR>Value: 
$<INPUT TYPE="text" NAME="amount" SIZE=8 MAXLENGTH=7 VALUE="<%= $cgi->param('amount') %>">
and/or
<INPUT TYPE="text" NAME="seconds" SIZE=6 MAXLENGTH=5 VALUE="<%= $cgi->param('seconds') %>">
<SELECT NAME="multiplier">
<% foreach my $multiplier ( keys %multiplier ) { %>
  <OPTION VALUE="<%= $multiplier %>"<%= $cgi->param('multiplier') eq $multiplier ? ' SELECTED' : '' %>><%= $multiplier{$multiplier} %>
<% } %>
</SELECT>
<BR><BR>
<INPUT TYPE="submit" NAME="submit" VALUE="Generate" onSubmit="this.disabled = true">

</FORM></BODY></HTML>

