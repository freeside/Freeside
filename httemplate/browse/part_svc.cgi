<!-- $Id: part_svc.cgi,v 1.2 2001-08-11 23:18:30 ivan Exp $ -->
<%= header('Service Part Listing', menubar( 'Main Menu' => $p) ) %>

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
     my(@rows)=
       grep $hashref->{${svcdb}.'__'.$_.'_flag'},
         map { /^${svcdb}__(.*)$/; $1 }
           grep ! /_flag$/,
             grep /^${svcdb}__/,
               fields('part_svc')
     ;
     my($rowspan)=scalar(@rows) || 1;
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
     my($row);
     foreach $row ( @rows ) {
       my($flag)=$part_svc->getfield($svcdb.'__'.$row.'_flag');
%>
     <%= $n1 %><TD><%= $row %></TD><TD>

<%     if ( $flag eq "D" ) { print "Default"; }
         elsif ( $flag eq "F" ) { print "Fixed"; }
         else { print "(Unknown!)"; }
%>
       </TD><TD><%= $part_svc->getfield($svcdb."__".$row) %></TD>
<%     $n1="</TR><TR>";
     }
%>
  </TR>
<% } %>

  <TR>
    <TD COLSPAN=2><A HREF="<%= $p %>edit/part_svc.cgi"><I>Add new service</I></A></TD>
  </TR>
</TABLE>
</BODY>
</HTML>
