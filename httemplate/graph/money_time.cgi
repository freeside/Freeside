<%

#	#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
#	my ($curmon,$curyear) = (localtime(time))[4,5];

#find first month
my $syear = $cgi->param('syear'); # || 1899+$curyear;
my $smonth = $cgi->param('smonth'); # || $curmon+1;

#find last month
my $eyear = $cgi->param('eyear'); # || 1900+$curyear;
my $emonth = $cgi->param('emonth'); # || $curmon+1;

#XXX or virtual
my( $agentnum, $agent ) = ('', '');
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
  $agent = qsearchs('agent', { 'agentnum' => $agentnum } );
  die "agentnum $agentnum not found!" unless $agent;
}
my $agentname = $agent ? $agent->agent.' ' : '';

%>
<%= include('/elements/header.html',
              $agentname. 'Sales, Credits and Receipts Summary'
           )
%>

<IMG SRC="money_time-graph.cgi?<%= $cgi->query_string %>" WIDTH="976" HEIGHT="384">
<BR>

<%= table('e8e8e8') %>
<%

my @items = qw( invoiced netsales credits payments receipts );
if ( $cgi->param('12mo') == 1 ) {
  @items = map $_.'_12mo', @items;
}

my %label = (
  'invoiced' => 'Gross Sales',
  'netsales' => 'Net Sales',
  'credits'  => 'Credits',
  'payments' => 'Gross Receipts',
  'receipts' => 'Net Receipts',
);
$label{$_.'_12mo'} = $label{$_}. " (previous 12 months)"
  foreach keys %label;

my %color = (
  'invoiced' => '9999ff', #light blue
  'netsales' => '0000cc', #blue
  'credits'  => 'cc0000', #red
  'payments' => '99cc99', #light green
  'receipts' => '00cc00', #green
);
$color{$_.'_12mo'} = $color{$_}
  foreach keys %color;

my %link = (
  'invoiced' => "${p}search/cust_bill.html?agentnum=$agentnum;",
  'credits'  => "${p}search/cust_credit.html?agentnum=$agentnum;",
  'payments' => "${p}search/cust_pay.cgi?magic=_date;agentnum=$agentnum;",
);
# XXX link 12mo?

my $report = new FS::Report::Table::Monthly (
  'items' => \@items,
  'start_month' => $smonth,
  'start_year'  => $syear,
  'end_month'   => $emonth,
  'end_year'    => $eyear,
  'agentnum'    => $agentnum,
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
  <TH>Total</TH>
</TR>

<% foreach my $row (@items) { %>
  <TR><TH><FONT COLOR="#<%= $color{$row} %>"><%= $label{$row} %></FONT></TH>
  <% my $link = exists($link{$row})
       ? qq(<A HREF="$link{$row})
       : '';
     my @speriod = @{$data->{speriod}};
     my @eperiod = @{$data->{eperiod}};
     my $total = 0;
  %>
  <% foreach my $column ( @{$data->{$row}} ) { %>
    <TD ALIGN="right" BGCOLOR="#ffffff">
      <%= $link ? $link. 'begin='. shift(@speriod). ';end='. shift(@eperiod). '">' : '' %><FONT COLOR="#<%= $color{$row} %>">$<%= sprintf("%.2f", $column) %></FONT><%= $link ? '</A>' : '' %>
    </TD>
    <% $total += $column; %>
  <% } %>
  <TD ALIGN="right" BGCOLOR="#f5f6be">
    <%= $link ? $link. 'begin='. @{$data->{speriod}}[0]. ';end='. @{$data->{eperiod}}[-1]. '">' : '' %><FONT COLOR="#<%= $color{$row} %>">$<%= sprintf("%.2f", $total) %></FONT><%= $link ? '</A>' : '' %>
  </TD>
  </TR>
<% } %>
</TABLE>

<%= include('/elements/footer.html') %>
