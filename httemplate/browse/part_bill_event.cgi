<% include("/elements/header.html",'Invoice Event Listing', menubar( 'Main Menu' => $p) ) %>

    Invoice events are actions taken on open invoices.<BR><BR>

<A HREF="<% $p %>edit/part_bill_event.cgi"><I>Add a new invoice event</I></A>
<BR><BR>

<% $total %> events
<% $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled events</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled events</a> )'; }
%>
<BR><BR>
% tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2longname;
%   tie my %freq, 'Tie::IxHash', '1d' => 'daily', '1m' => 'monthly';
%   foreach my $payby ( keys %payby ) {
%     my $oldfreq = '';
%
%     my @payby_part_bill_event =
%       grep { $payby eq $_->payby }
%       sort {    ( $a->freq || '1d') cmp ( $b->freq || '1d' ) # for now
%              ||   $a->seconds       <=>   $b->seconds
%              ||   $a->weight        <=>   $b->weight
%              ||   $a->eventpart     <=>   $b->eventpart
%            }
%       @part_bill_event;
%
%
% if ( @payby_part_bill_event ) { 


    <% include('/elements/table-grid.html') %>
% my $bgcolor1 = '#eeeeee';
%       my $bgcolor2 = '#ffffff';
%       my $bgcolor;
%    
%
%       foreach my $part_bill_event ( @payby_part_bill_event ) {
%         my $url = "${p}edit/part_bill_event.cgi?". $part_bill_event->eventpart;
%         my $delay = duration_exact($part_bill_event->seconds);
%         ( my $plandata = $part_bill_event->plandata ) =~ s/\n/<BR>/go;
%         my $freq = $part_bill_event->freq || '1d';
%         my $reason = $part_bill_event->reasontext ;
%    
% if ( $oldfreq ne $freq ) { 

  
        <TR>
          <TH CLASS="grid" BGCOLOR="#999999" COLSPAN=<% $cgi->param('showdisabled') ? 7 : 8 %>><% ucfirst($freq{$freq}) %> event tests for <FONT SIZE="+1"><I><% $payby{$payby} %> customers</I></FONT></TH>
        </TR>
      
        <TR>
          <TH CLASS="grid" BGCOLOR="#cccccc" COLSPAN=<% $cgi->param('showdisabled') ? 2 : 3 %>>Event</TH>
          <TH CLASS="grid" BGCOLOR="#cccccc">After</TH>
          <TH CLASS="grid" BGCOLOR="#cccccc">Action</TH>
          <TH CLASS="grid" BGCOLOR="#cccccc">Reason</TH>
          <TH CLASS="grid" BGCOLOR="#cccccc">Options</TH>
          <TH CLASS="grid" BGCOLOR="#cccccc">Code</TH>
        </TR>
%
%           $oldfreq = $freq;
%           $bgcolor = '';
%        
% } 
%
%         if ( $bgcolor eq $bgcolor1 ) {
%            $bgcolor = $bgcolor2;
%          } else {
%            $bgcolor = $bgcolor1;
%          }
%      

  
      <TR>
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><A HREF="<% $url %>">
          <% $part_bill_event->eventpart %></A></TD>
% unless ( $cgi->param('showdisabled') ) { 

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $part_bill_event->disabled ? 'DISABLED' : '' %></TD>
% } 

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><A HREF="<% $url %>">
          <% $part_bill_event->event %></A></TD>
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $delay %></TD>
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $part_bill_event->plan %></TD>
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $reason %></TD>
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <% $plandata %></TD>
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><FONT SIZE="-1">
          <% $part_bill_event->eventcode %></FONT></TD>
      </TR>
% } 

    </TABLE>
    <BR><BR>
% } 
% } 


</BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my %search;
if ( $cgi->param('showdisabled') ) {
%search = ();
} else {
%search = ( 'disabled' => '' );
}

my @part_bill_event = qsearch('part_bill_event', \%search );
my $total = scalar(@part_bill_event);

</%init>
