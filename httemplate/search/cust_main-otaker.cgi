<HTML>
  <HEAD>
    <TITLE>Customer Search</TITLE>
  </HEAD>
  <BODY BGCOLOR="#e8e8e8">
    <FONT SIZE=7>
      Customer Search
    </FONT>
    <BR>
    <FORM ACTION="cust_main.cgi" METHOD="GET">
      Search for <B>Order taker</B>: 
      <INPUT TYPE="hidden" NAME="otaker_on" VALUE="TRUE">
      <% my $sth = dbh->prepare("SELECT DISTINCT otaker FROM cust_main")
           or die dbh->errstr;
         $sth->execute() or die $sth->errstr;
#         my @otakers = map { $_->[0] } @{$sth->selectall_arrayref};
      %>
      <SELECT NAME="otaker">
      <% my $otaker; while ( $otaker = $sth->fetchrow_arrayref ) { %>
        <OPTION><%= $otaker->[0] %></OTAKER>
      <% } %>
      </SELECT>
      <P><INPUT TYPE="submit" VALUE="Search">

    </FORM>
  </BODY>
</HTML>

