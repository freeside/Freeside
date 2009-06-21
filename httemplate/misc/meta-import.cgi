<% include('/elements/header.html', 'Import') %>

<FORM ACTION="process/meta-import.cgi" METHOD="post" ENCTYPE="multipart/form-data">
Import data from a DBI data source<BR><BR>
%
%  #false laziness with edit/cust_main.cgi
%  my @agents = qsearch( 'agent', {} );
%  die "No agents created!" unless @agents;
%  my $agentnum = $agents[0]->agentnum; #default to first
%
%  if ( scalar(@agents) == 1 ) {
%

    <INPUT TYPE="hidden" NAME="agentnum" VALUE="<% $agentnum %>">
% } else { 

    <BR><BR>Agent <SELECT NAME="agentnum" SIZE="1">
% foreach my $agent (sort { $a->agent cmp $b->agent } @agents) { 

    <OPTION VALUE="<% $agent->agentnum %>" <% " SELECTED"x($agent->agentnum==$agentnum) %>><% $agent->agent %></OPTION>
% } 

    </SELECT><BR><BR>
% } 
%
%  my @referrals = qsearch('part_referral',{});
%  die "No advertising sources created!" unless @referrals;
%  my $refnum = $referrals[0]->refnum; #default to first
%
%  if ( scalar(@referrals) == 1 ) {
%

    <INPUT TYPE="hidden" NAME="refnum" VALUE="<% $refnum %>">
% } else { 

    <BR><BR>Advertising source <SELECT NAME="refnum" SIZE="1">
% foreach my $referral ( sort { $a->referral <=> $b->referral } @referrals) { 

    <OPTION VALUE="<% $referral->refnum %>" <% " SELECTED"x($referral->refnum==$refnum) %>><% $referral->refnum %>: <% $referral->referral %></OPTION>
% } 

    </SELECT><BR><BR>
% } 


    First package: <SELECT NAME="pkgpart"><OPTION VALUE="">(none)</OPTION>
% foreach my $part_pkg ( qsearch('part_pkg',{'disabled'=>'' }) ) { 

     <OPTION VALUE="<% $part_pkg->pkgpart %>"><% $part_pkg->pkg_comment %></OPTION>
% } 

</SELECT><BR><BR>

  <table>
    <tr>
      <td align="right">DBI data source: </td>
      <td><INPUT TYPE="text" NAME="data_source"></td>
    </tr>
    <tr>
      <td align="right">DBI username: </td>
      <td><INPUT TYPE="text" NAME="username"></td>
    </tr>
    <tr>
      <td align="right">DBI password: </td>
      <td><INPUT TYPE="text" NAME="password"></td>
    </tr>
  </table>
  <INPUT TYPE="submit" VALUE="Import">

  </FORM>

<% include('/elements/footer.html') %>

<%init>

#there's no ACL for this...  haven't used in ages
die 'meta-import not enabled; remove this if you want to use it';

</%init>
