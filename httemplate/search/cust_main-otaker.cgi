<% include('/elements/header.html', 'Customer Search' ) %>

<FORM ACTION="cust_main.cgi" METHOD="GET">

Search for <B>Order taker</B>: 
  <INPUT TYPE="hidden" NAME="otaker_on" VALUE="TRUE">
% my $sth = dbh->prepare("SELECT DISTINCT otaker FROM cust_main")
%     or die dbh->errstr;
%   $sth->execute() or die $sth->errstr;
%   #my @otakers = map { $_->[0] } @{$sth->fetchall_arrayref};
%

<SELECT NAME="otaker">
% my $otaker; while ( $otaker = $sth->fetchrow_arrayref ) { 

  <OPTION><% $otaker->[0] %>
% } 

</SELECT>

<P><INPUT TYPE="submit" VALUE="Search">

</FORM>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

</%init>
