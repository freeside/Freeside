<!-- mason kludge -->
<%

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_external = qsearchs( 'svc_external', { 'svcnum' => $svcnum } )
  or die "svc_external: Unknown svcnum $svcnum";

#false laziness w/all svc_*.cgi
my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $svcnum } );
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum);
if ($pkgnum) {
  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
  $custnum = $cust_pkg->custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}
#eofalse

%>

<%= header('External Service View', menubar(
  ( ( $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )                                                                       
    : ( "Cancel this (unaudited) external service" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
)) %>

<A HREF="<%=$p%>edit/svc_external.cgi?<%=$svcnum%>">Edit this information</A><BR>
<%= ntable("#cccccc") %><TR><TD><%= ntable("#cccccc",2) %>

<TR><TD ALIGN="right">Service number</TD>
  <TD BGCOLOR="#ffffff"><%= $svcnum %></TD></TR>
<TR><TD ALIGN="right">External ID</TD>
  <TD BGCOLOR="#ffffff"><%= $svc_external->id %></TD></TR>
<TR><TD ALIGN="right">Title</TD>
  <TD BGCOLOR="#ffffff"><%= $svc_external->title %></TD></TR>

<% foreach (sort { $a cmp $b } $svc_external->virtual_fields) { %>
  <%= $svc_external->pvf($_)->widget('HTML', 'view', $svc_external->getfield($_)) %>
<% } %>

</TABLE></TD></TR></TABLE>
<BR><%= joblisting({'svcnum'=>$svcnum}, 1) %>
</BODY></HTML>
