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
    <TITLE>Sales, Credits and Receipts Summary</TITLE>
  </HEAD>
<BODY BGCOLOR="#e8e8e8">
<IMG SRC="money_time-graph.cgi?<%= $cgi->query_string %>" WIDTH="976" HEIGHT="384">
<BR>

<%= table('e8e8e8') %>
<%

my @items = qw( invoiced netsales credits payments receipts );
my %label = (
  'invoiced' => 'Gross Sales',
  'netsales' => 'Net Sales',
  'credits'  => 'Credits',
  'payments' => 'Gross Receipts',
  'receipts' => 'Net Receipts',
);
my %color = (
  'invoiced' => '9999ff', #light blue
  'netsales' => '0000cc', #blue
  'credits'  => 'cc0000', #red
  'payments' => '99cc99', #light green
  'receipts' => '00cc00', #green
);
my %link = (
  'invoiced' => "${p}search/cust_bill.html?",
  'credits'  => "${p}search/cust_credit.html?",
  'payments' => "${p}search/cust_pay.cgi?magic=_date;",
);

my $report = new FS::Report::Table::Monthly (
  'items' => \@items,
  'start_month' => $smonth,
  'start_year'  => $syear,
  'end_month'   => $emonth,
  'end_year'    => $eyear,
);
my $data = $report->data;

my @mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

%>

<TR><TD></TD>
<% foreach my $column ( @{$data->{label}} ) {
     #$column =~ s/^(\d+)\//$mon[$1-1]<BR>/e;
     $column =~ s/^(\d+)\//$mon[$1-1]<BR>/;
     %>
     <TH><%= $column %></TH>
<% } %>
</TR>

<% foreach my $row (@items) { %>
  <TR><TH><FONT COLOR="#<%= $color{$row} %>"><%= $label{$row} %></FONT></TH>
  <% my $link = exists($link{$row})
       ? qq(<A HREF="$link{$row})
       : '';
     my @speriod = @{$data->{speriod}};
     my @eperiod = @{$data->{eperiod}};
  %>
  <% foreach my $column ( @{$data->{$row}} ) { %>
    <TD ALIGN="right" BGCOLOR="#ffffff">
      <%= $link ? $link. 'begin='. shift(@speriod). ';end='. shift(@eperiod). '">' : '' %><FONT COLOR="#<%= $color{$row} %>">$<%= sprintf("%.2f", $column) %></FONT><%= $link ? '</A>' : '' %>
    </TD>
  <% } %>
  </TR>
<% } %>
</TABLE>

<BR>
<FORM METHOD="POST">
<!--
<INPUT TYPE="checkbox" NAME="ar">
  Accounts receivable (invoices - applied credits)<BR>
<INPUT TYPE="checkbox" NAME="charged">
  Just Invoices<BR>
<INPUT TYPE="checkbox" NAME="defer">
  Accounts receivable, with deferred revenue (invoices - applied credits, with charges for annual/semi-annual/quarterly/etc. services deferred over applicable time period) (there has got to be a shorter description for this)<BR>
<INPUT TYPE="checkbox" NAME="cash">
  Cashflow (payments - refunds)<BR>
<BR>
-->
From <SELECT NAME="smonth">
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

<INPUT TYPE="submit" VALUE="Redisplay">
</FORM>
</BODY>
</HTML>
