<!-- mason kludge -->
<%

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_broadband = qsearchs( 'svc_broadband', { 'svcnum' => $svcnum } )
  or die "svc_broadband: Unknown svcnum $svcnum";

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

my $router = $svc_broadband->addr_block->router;

if (not $router) { die "Could not lookup router for svc_broadband (svcnum $svcnum)" };

my (
     $routername,
     $routernum,
     $speed_down,
     $speed_up,
     $ip_addr
   ) = (
     $router->getfield('routername'),
     $router->getfield('routernum'),
     $svc_broadband->getfield('speed_down'),
     $svc_broadband->getfield('speed_up'),
     $svc_broadband->getfield('ip_addr')
   );
%>

<%=header('Broadband Service View', menubar(
  ( ( $custnum )
    ? ( "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )                                                                       
    : ( "Cancel this (unaudited) website" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
))
%>

<A HREF="<%=${p}%>edit/svc_broadband.cgi?<%=$svcnum%>">Edit this information</A>
<BR>
<%=ntable("#cccccc")%>
  <TR>
    <TD>
      <%=ntable("#cccccc",2)%>
        <TR>
          <TD ALIGN="right">Service number</TD>
          <TD BGCOLOR="#ffffff"><%=$svcnum%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Router</TD>
          <TD BGCOLOR="#ffffff"><%=$routernum%>: <%=$routername%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Download Speed</TD>
          <TD BGCOLOR="#ffffff"><%=$speed_down%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">Upload Speed</TD>
          <TD BGCOLOR="#ffffff"><%=$speed_up%></TD>
        </TR>
        <TR>
          <TD ALIGN="right">IP Address</TD>
          <TD BGCOLOR="#ffffff"><%=$ip_addr%></TD>
        </TR>
        <TR COLSPAN="2"><TD></TD></TR>

<%
foreach (sort { $a cmp $b } $svc_broadband->virtual_fields) {
  print $svc_broadband->pvf($_)->widget('HTML', 'view',
                                        $svc_broadband->getfield($_)), "\n";
}

%>
      </TABLE>
    </TD>
  </TR>
</TABLE>

<BR>
<%=ntable("#cccccc", 2)%>
<%
  my $sb_router = qsearchs('router', { svcnum => $svcnum });
  if ($sb_router) {
  %>
  <B>Router associated: <%=$sb_router->routername%> </B>
  <A HREF="<%=popurl(2)%>edit/router.cgi?<%=$sb_router->routernum%>">
    (details)
  </A>
  <BR>
  <% my @addr_block;
     if (@addr_block = $sb_router->addr_block) {
     %>
  <B>Address space </B>
  <A HREF="<%=popurl(2)%>browse/addr_block.cgi">
    (edit)
  </A>
  <BR>
  <%   print ntable("#cccccc", 1);
       foreach (@addr_block) { %>
    <TR>
      <TD><%=$_->ip_gateway%>/<%=$_->ip_netmask%></TD>
    </TR>
    <% } %>
  </TABLE>
  <% } else { %>
  <B>No address space allocated.</B>
    <% } %>
  <BR>
  <%
  } else {
%>

<FORM METHOD="GET" ACTION="<%=popurl(2)%>edit/router.cgi">
  <INPUT TYPE="hidden" NAME="svcnum" VALUE="<%=$svcnum%>">
Add router named 
  <INPUT TYPE="text" NAME="routername" SIZE="32" VALUE="Broadband router (<%=$svcnum%>)">
  <INPUT TYPE="submit" VALUE="Add router">
</FORM>

<%
}
%>

<BR>
<%=joblisting({'svcnum'=>$svcnum}, 1)%>
  </BODY>
</HTML>

