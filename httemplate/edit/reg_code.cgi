%
%my $agentnum = $cgi->param('agentnum');
%$agentnum =~ /^(\d+)$/ or eidiot "illegal agentnum $agentnum";
%$agentnum = $1;
%my $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
%
%


<% include("/elements/header.html",'Generate registration codes for '. $agent->agent, menubar(
      'Main Menu' => $p,
    ))
%>
% if ( $cgi->param('error') ) { 

  <FONT SIZE="+1" COLOR="#FF0000">Error: <% $cgi->param('error') %></FONT>
% } 


<FORM ACTION="<%popurl(1)%>process/reg_code.cgi" METHOD="POST" NAME="OneTrueForm" onSubmit="document.OneTrueForm.submit.disabled=true">
<INPUT TYPE="hidden" NAME="agentnum" VALUE="<% $agent->agentnum %>">

Generate
<INPUT TYPE="text" NAME="num" VALUE="<% $cgi->param('num') %>" SIZE=5 MAXLENGTH=4>
registration codes for <B><% $agent->agent %></B> allowing the following packages:
<BR><BR>
% foreach my $part_pkg ( qsearch('part_pkg', { 'disabled' => '' } ) ) { 

  <INPUT TYPE="checkbox" NAME="pkgpart<% $part_pkg->pkgpart %>">
  <% $part_pkg->pkg %> - <% $part_pkg->comment %>
  <BR>
% } 


<BR>
<INPUT TYPE="submit" NAME="submit" VALUE="Generate">

</FORM></BODY></HTML>

