<% include("/elements/header.html",'Access Number Listing', menubar( 'Main Menu' => $p )) %>
Points of Presence<BR><BR>
<A HREF="<% $p %>edit/svc_acct_pop.cgi"><I>Add new Access Number</I></A><BR><BR>
<% table() %>
      <TR>
        <TH></TH>
        <TH>City</TH>
        <TH>State</TH>
        <TH>Area code</TH>
        <TH>Exchange</TH>
        <TH>Local</TH>
        <TH>Accounts</TH>
      </TR>
%
%foreach my $svc_acct_pop ( sort { 
%  #$a->getfield('popnum') <=> $b->getfield('popnum')
%  $a->state cmp $b->state || $a->city cmp $b->city
%    || $a->ac <=> $b->ac || $a->exch <=> $b->exch || $a->loc <=> $b->loc
%} qsearch('svc_acct_pop',{}) ) {
%
%  my $svc_acct_pop_link = $p . 'edit/svc_acct_pop.cgi?'. $svc_acct_pop->popnum;
%
%  $accounts_sth->execute($svc_acct_pop->popnum) or die $accounts_sth->errstr;
%  my $num_accounts = $accounts_sth->fetchrow_arrayref->[0];
%
%  my $svc_acct_link = $p. 'search/svc_acct.cgi?popnum='. $svc_acct_pop->popnum;
%
%

      <TR>
        <TD><A HREF="<% $svc_acct_pop_link %>">
          <% $svc_acct_pop->popnum %></A></TD>
        <TD><A HREF="<% $svc_acct_pop_link %>">
          <% $svc_acct_pop->city %></A></TD>
        <TD><A HREF="<% $svc_acct_pop_link %>">
          <% $svc_acct_pop->state %></A></TD>
        <TD><A HREF="<% $svc_acct_pop_link %>">
          <% $svc_acct_pop->ac %></A></TD>
        <TD><A HREF="<% $svc_acct_pop_link %>">
          <% $svc_acct_pop->exch %></A></TD>
        <TD><A HREF="<% $svc_acct_pop_link %>">
          <% $svc_acct_pop->loc %></A></TD>
        <TD>
          <FONT COLOR="#00CC00"><B><% $num_accounts %></B></FONT>
% if ( $num_accounts ) { 
<A HREF="<% $svc_acct_link %>">
% } 

            active
% if ( $num_accounts ) { 
</A>
% } 

        </TD>
      </TR>
% } 


      <TR>
      </TR>
    </TABLE>
  </BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $accounts_sth = dbh->prepare("SELECT COUNT(*) FROM svc_acct
                                   WHERE popnum = ?           ")
  or die dbh->errstr;

</%init>
