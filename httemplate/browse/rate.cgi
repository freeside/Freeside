<!-- mason kludge -->
<%= header("Rate plan listing", menubar( 'Main Menu' => "$p#sysadmin" )) %>
Rate plans, regions and prefixes for VoIP and call billing.<BR><BR>
<A HREF="<%=$p%>edit/rate.cgi"><I>Add a rate plan</I></A>
| <A HREF="<%=$p%>edit/rate_region.cgi"><I>Add a region</I></A>
<BR><BR>
<SCRIPT>
function rate_areyousure(href) {
  if (confirm("Are you sure you want to delete this rate plan?") == true)
    window.location.href = href;
}
</SCRIPT>

<%= table() %>
  <TR>
    <TH COLSPAN=2>Rate plan</TH>
  </TR>

<% foreach my $rate ( sort { 
     $a->getfield('ratenum') <=> $b->getfield('ratenum')
   } qsearch('rate',{}) ) {
%>
  <TR>
    <TD><A HREF="<%= $p %>edit/rate.cgi?<%= $rate->ratenum %>"><%= $rate->ratenum %></A></TD>
    <TD><A HREF="<%= $p %>edit/rate.cgi?<%= $rate->ratenum %>"><%= $rate->ratename %></A></TD>
  </TR>

<% } %>

</TABLE>
</BODY>
</HTML>

 
