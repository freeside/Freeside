<!-- $Id: part_svc.cgi,v 1.6 2001-12-27 09:26:14 ivan Exp $ -->
<% 

my %search;
if ( $cgi->param('showdisabled') ) {
  %search = ();
} else {
  %search = ( 'disabled' => '' );
}

my @part_svc = qsearch('part_svc', \%search );
my $total = scalar(@part_svc);

%>
<%= header('Service Definition Listing', menubar( 'Main Menu' => $p) ) %>

    Services are items you offer to your customers.<BR><BR>
<%= $total %> services
<%= $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled services</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled services</a> )'; }
%>
<TABLE BORDER=1>
  <TR>
    <TH COLSPAN=<%= $cgi->param('showdisabled') ? 2 : 3 %>>Service</TH>
    <TH>Table</TH>
    <TH>Field</TH>
    <TH COLSPAN=2>Modifier</TH>
  </TR>

<% foreach my $part_svc ( sort {
     $a->getfield('svcpart') <=> $b->getfield('svcpart')
   } @part_svc ) {
     my($hashref)=$part_svc->hashref;
     my($svcdb)=$hashref->{svcdb};
     my @fields =
       grep { $_ ne 'svcnum' && $part_svc->part_svc_column($_)->columnflag }
            fields($svcdb);

     my($rowspan)=scalar(@fields) || 1;
     my $url = "${p}edit/part_svc.cgi?$hashref->{svcpart}";
%>

  <TR>
    <TD ROWSPAN=<%= $rowspan %>><A HREF="<%= $url %>">
      <%= $hashref->{svcpart} %></A></TD>
<% unless ( $cgi->param('showdisabled') ) { %>
    <TD ROWSPAN=<%= $rowspan %>>
      <%= $hashref->{disabled} ? 'DISABLED' : '' %></TD>
<% } %>
    <TD ROWSPAN=<%= $rowspan %>><A HREF="<%= $url %>">
      <%= $hashref->{svc} %></A></TD>
    <TD ROWSPAN=<%= $rowspan %>>
      <%= $hashref->{svcdb} %></TD>

<%   my($n1)='';
     foreach my $field ( @fields ) {
       my $flag = $part_svc->part_svc_column($field)->columnflag;
%>
     <%= $n1 %><TD><%= $field %></TD><TD>

<%     if ( $flag eq "D" ) { print "Default"; }
         elsif ( $flag eq "F" ) { print "Fixed"; }
         else { print "(Unknown!)"; }
%>
       </TD><TD><%= $part_svc->part_svc_column($field)->columnvalue%></TD>
<%     $n1="</TR><TR>";
     }
%>
  </TR>
<% } %>

  <TR>
    <TD COLSPAN=6><A HREF="<%= $p %>edit/part_svc.cgi"><I>Add a new service definition</I></A></TD>
  </TR>
</TABLE>
</BODY>
</HTML>
