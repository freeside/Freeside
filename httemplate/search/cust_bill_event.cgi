<!-- mason kludge -->
<%

#false laziness with view/cust_bill.cgi

$cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
my $beginning = str2time($1) || 0;

$cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
my $ending =  ( $1 ? str2time($1) : 4294880896 ) + 86399;

my @cust_bill_event =
  sort { $a->_date <=> $b->_date }
    qsearch('cust_bill_event', {
      _date => { op=> '>=', value=>$beginning },
      statustext => { op=> '!=', value=>'' },
# i wish...
#      _date => { op=> '<=', value=>$ending },
    }, '', "AND _date <= $ending");

%>

<%= header('Failed billing events') %>

<%= table() %>
<TR>
  <TH>Event</TH>
  <TH>Date</TH>
  <TH>Status</TH>
  <TH>Invoice</TH>
  <TH>(bill) name</TH>
  <TH>company</TH>
<% if ( defined dbdef->table('cust_main')->column('ship_last') ) { %>
  <TH>(service) name</TH>
  <TH>company</TH>
<% } %>
</TR>

<% foreach my $cust_bill_event ( @cust_bill_event ) {
   my $status = $cust_bill_event->status;
   $status .= ': '.$cust_bill_event->statustext if $cust_bill_event->statustext;
   my $cust_bill = $cust_bill_event->cust_bill;
   my $cust_main = $cust_bill->cust_main;
   my $invlink = "${p}view/cust_bill.cgi?". $cust_bill->invnum;
   my $custlink = "${p}view/cust_main.cgi?". $cust_main->custnum;
%>
<TR>
  <TD><%= $cust_bill_event->part_bill_event->event %></TD>
  <TD><%= time2str("%a %b %e %T %Y", $cust_bill_event->_date) %></TD>
  <TD><%= $status %></TD>
  <TD><A HREF="<%=$invlink%>">Invoice #<%= $cust_bill->invnum %> (<%= time2str("%D", $cust_bill->_date ) %>)</A></TD>
  <TD><A HREF="<%=$custlink%>"><%= $cust_main->last. ', '. $cust_main->first %></A></TD>
  <TD><A HREF="<%=$custlink%>"><%= $cust_main->company %></A></TD>
  <% if ( defined dbdef->table('cust_main')->column('ship_last') ) { %>
    <TD><A HREF="<%=$custlink%>"><%= $cust_main->ship_last. ', '. $cust_main->ship_first %></A></TD>
    <TD><A HREF="<%=$custlink%>"><%= $cust_main->ship_company %></A></TD>
  <% } %>
</TR>
<% } %>
</TABLE>

</BODY></HTML>
