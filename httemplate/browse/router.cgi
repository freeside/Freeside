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
<% foreach my $router (sort {$a->routernum <=> $b->routernum} @router) {
     my @addr_block = $router->addr_block;
     if (scalar(@addr_block) == 0) {
       push @addr_block, '&nbsp;';
     }
%>
  <TR>
    <TD ROWSPAN="<%=scalar(@addr_block)+1%>">
      <A HREF="<%=$p2%>edit/router.cgi?<%=$router->routernum%>"><%=$router->routername%></A>
    </TD>
  </TR>
  <% foreach my $block ( @addr_block ) { %>
  <TR>
    <TD><%=UNIVERSAL::isa($block, 'FS::addr_block') ? $block->NetAddr : '&nbsp;'%></TD>
  </TR>
  <% } %>
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>

