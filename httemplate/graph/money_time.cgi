<!-- mason kludge -->
<%

#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my ($curmon,$curyear) = (localtime(time))[4,5];

#find first month
my $syear = $cgi->param('syear') || 1899+$curyear;
my $smonth = $cgi->param('smonth') || $curmon+1;

#find last month
my $eyear = $cgi->param('eyear') || 1900+$curyear;
my $emonth = $cgi->param('emonth') || $curmon+1;

%>

<HTML>
  <HEAD>
    <TITLE>Graphing monetary values over time</TITLE>
  </HEAD>
<BODY BGCOLOR="#e8e8e8">
<IMG SRC="money_time-graph.cgi?<%= $cgi->query_string %>" WIDTH="768" HEIGHT="480">
<BR>
<FORM METHOD="POST">
<INPUT TYPE="checkbox" NAME="ar">
  Accounts receivable (invoices - applied credits)<BR>
<INPUT TYPE="checkbox" NAME="charged">
  Just Invoices<BR>
<INPUT TYPE="checkbox" NAME="defer">
  Accounts receivable, with deferred revenue (invoices - applied credits, with charges for annual/semi-annual/quarterly/etc. services deferred over applicable time period) (there has got to be a shorter description for this)<BR>
<INPUT TYPE="checkbox" NAME="cash">
  Cashflow (payments - refunds)<BR>
<BR>
From <SELECT NAME="smonth">
<% my @mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec); %>
<% foreach my $mon ( 1..12 ) { %>
<OPTION VALUE="<%= $mon %>"<%= $mon == $smonth ? ' SELECTED' : '' %>><%= $mon[$mon-1] %>
<% } %>
</SELECT>
<SELECT NAME="syear">
<% foreach my $y ( 1999 .. 2010 ) { %>
<OPTION VALUE="<%= $y %>"<%= $y == $syear ? ' SELECTED' : '' %>><%= $y %>
<% } %>
</SELECT>
 to <SELECT NAME="emonth">
<% foreach my $mon ( 1..12 ) { %>
<OPTION VALUE="<%= $mon %>"<%= $mon == $emonth ? ' SELECTED' : '' %>><%= $mon[$mon-1] %>
<% } %>
</SELECT>
<SELECT NAME="eyear">
<% foreach my $y ( 1999 .. 2010 ) { %>
<OPTION VALUE="<%= $y %>"<%= $y == $eyear ? ' SELECTED' : '' %>><%= $y %>
<% } %>
</SELECT>

<INPUT TYPE="submit" VALUE="Graph">
</FORM>
</BODY>
</HTML>
