<!-- mason kludge -->
<% 

my %search;
if ( $cgi->param('showdisabled') ) {
  %search = ();
} else {
  %search = ( 'disabled' => '' );
}

my @part_bill_event = qsearch('part_bill_event', \%search );
my $total = scalar(@part_bill_event);

%>
<%= header('Invoice Event Listing', menubar( 'Main Menu' => $p) ) %>

    Invoice events are actions taken on overdue invoices.<BR><BR>
<A HREF="<%= $p %>edit/part_bill_event.cgi"><I>Add a new invoice event</I></A>
<BR><BR>
<%= $total %> events
<%= $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled events</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled events</a> )'; }
%>
<%= table() %>
  <TR>
    <TH COLSPAN=<%= $cgi->param('showdisabled') ? 2 : 3 %>>Event</TH>
    <TH>Payby</TH>
    <TH>After</TH>
    <TH>Action</TH>
    <TH>Options</TH>
    <TH>Code</TH>
  </TR>

<% foreach my $part_bill_event ( sort {    $a->payby     cmp $b->payby
                                        || $a->seconds   <=> $b->seconds
                                        || $a->weight    <=> $b->weight
                                        || $a->eventpart <=> $b->eventpart
                                      } @part_bill_event ) {
     my $url = "${p}edit/part_bill_event.cgi?". $part_bill_event->eventpart;
     use Time::Duration;
     my $delay = duration_exact($part_bill_event->seconds);
     my $plandata = $part_bill_event->plandata;
     $plandata =~ s/\n/<BR>/go;
%>
  <TR>
    <TD><A HREF="<%= $url %>">
      <%= $part_bill_event->eventpart %></A></TD>
<% unless ( $cgi->param('showdisabled') ) { %>
    <TD>
      <%= $part_bill_event->disabled ? 'DISABLED' : '' %></TD>
<% } %>
    <TD><A HREF="<%= $url %>">
      <%= $part_bill_event->event %></A></TD>
    <TD>
      <%= $part_bill_event->payby %></TD>
    <TD>
      <%= $delay %></TD>
    <TD>
      <%= $part_bill_event->plan %></TD>
    <TD>
      <%= $plandata %></TD>
    <TD><FONT SIZE="-1">
      <%= $part_bill_event->eventcode %></FONT></TD>
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>
