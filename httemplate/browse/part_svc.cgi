<!-- $Id: part_svc.cgi,v 1.5 2001-09-11 00:08:18 ivan Exp $ -->
<%= header('Service Definition Listing', menubar( 'Main Menu' => $p) ) %>

    Services are items you offer to your customers.<BR><BR>
<TABLE BORDER=1>
  <TR>
    <TH COLSPAN=2>Service</TH>
    <TH>Table</TH>
    <TH>Field</TH>
    <TH COLSPAN=2>Modifier</TH>
  </TR>

<% foreach my $part_svc ( sort {
     $a->getfield('svcpart') <=> $b->getfield('svcpart')
   } qsearch('part_svc',{}) ) {
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
