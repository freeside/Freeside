<!-- mason kludge -->
<%= header('Batch Customer Import') %>
<FORM ACTION="process/cust_main-import.cgi" METHOD="post" ENCTYPE="multipart/form-data">
Import a CSV file containing customer records.<BR><BR>
Default file format is CSV, with the following field order: <i>cust_pkg.setup, dayphone, first, last, address1, address2, city, state, zip, comments</i><BR><BR>

<%
  #false laziness with edit/cust_main.cgi
  my @agents = qsearch( 'agent', {} );
  die "No agents created!" unless @agents;
  my $agentnum = $agents[0]->agentnum; #default to first

  if ( scalar(@agents) == 1 ) {
%>
    <INPUT TYPE="hidden" NAME="agentnum" VALUE="<%= $agentnum %>">
<% } else { %>
    <BR><BR>Agent <SELECT NAME="agentnum" SIZE="1">
  <% foreach my $agent (sort { $a->agent cmp $b->agent } @agents) { %>
    <OPTION VALUE="<%= $agent->agentnum %>" <%= " SELECTED"x($agent->agentnum==$agentnum) %>><%= $agent->agent %></OPTION>
  <% } %>
    </SELECT><BR><BR>
<% } %>

<%
  my @referrals = qsearch('part_referral',{});
  die "No advertising sources created!" unless @referrals;
  my $refnum = $referrals[0]->refnum; #default to first

  if ( scalar(@referrals) == 1 ) {
%>
    <INPUT TYPE="hidden" NAME="refnum" VALUE="<%= $refnum %>">
<% } else { %>
    <BR><BR>Advertising source <SELECT NAME="refnum" SIZE="1">
  <% foreach my $referral ( sort { $a->referral <=> $b->referral } @referrals) { %>
    <OPTION VALUE="<%= $referral->refnum %>" <%= " SELECTED"x($referral->refnum==$refnum) %>><%= $referral->refnum %>: <%= $referral->referral %></OPTION>
  <% } %>
    </SELECT><BR><BR>
<% } %>

    First package: <SELECT NAME="pkgpart"><OPTION VALUE="">(none)</OPTION>
<% foreach my $part_pkg ( qsearch('part_pkg',{'disabled'=>'' }) ) { %>
     <OPTION VALUE="<%= $part_pkg->pkgpart %>"><%= $part_pkg->pkg. ' - '. $part_pkg->comment %></OPTION>
<% } %>
</SELECT><BR><BR>

    CSV Filename: <INPUT TYPE="file" NAME="csvfile"><BR><BR>
    <INPUT TYPE="submit" VALUE="Import">
    </FORM>
  </BODY>
<HTML>

