<%= header('Routers', menubar('Main Menu'   => $p)) %>
<%

my @router = qsearch('router', {});
my $p2 = popurl(2);

%>

<% if ($cgi->param('error')) { %>
   <FONT SIZE="+1" COLOR="#ff0000">Error: <%=$cgi->param('error')%></FONT>
   <BR><BR>
<% } %>

<A HREF="<%=$p2%>edit/router.cgi"><I>Add a new router</I></A><BR><BR>

<%=table()%>
  <TR>
    <TD><B>Router name</B></TD>
    <TD><B>Address block(s)</B></TD>
  </TR>
<% foreach $router (sort {$a->routernum <=> $b->routernum} @router) {
     my @addr_block = $router->addr_block;
%>
  <TR>
    <TD ROWSPAN="<%=scalar(@addr_block)%>">
      <A HREF="<%=$p2%>edit/router.cgi?<%=$router->routernum%>"><%=$router->routername%></A>
    </TD>
    <TD>
    <% foreach my $block ( @addr_block ) { %>
      <%=$block->NetAddr%></BR>
    <% } %>
    </TD>
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>

