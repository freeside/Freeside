<HTML>
  <HEAD>
    <TITLE>Graphing monetary values over time</TITLE>
  </HEAD>
<BODY BGCOLOR="#e8e8e8">
<IMG SRC="money_time-graph.cgi" WIDTH="768" HEIGHT="480">
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
<% my @m = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
   foreach my $m ( 1..12 ) { %>
<OPTION VALUE="<%= $m %>"><%= $m[$m-1] %>
<% } %>
</SELECT>
<SELECT NAME="syear">
<% foreach my $y ( 1999 .. 2010 ) { %>
<OPTION VALUE="<%= $y %>"><%= $y %>
<% } %>
</SELECT>
 to <SELECT NAME="emonth">
<% foreach my $m ( 1..12 ) { %>
<OPTION VALUE="<%= $m %>"><%= $m[$m-1] %>
<% } %>
</SELECT>
<SELECT NAME="eyear">
<% foreach my $y ( 1999 .. 2010 ) { %>
<OPTION VALUE="<%= $y %>"><%= $y %>
<% } %>
</SELECT>

<INPUT TYPE="submit" VALUE="Graph">
</FORM>
</BODY>
</HTML>
