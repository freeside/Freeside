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
<!-- <TH><TD>Field name</TD><TD>Field value</TD></TH> -->
<% foreach $router (sort {$a->routernum <=> $b->routernum} @router) { %>
  <TR>
<!--    <TD ROWSPAN="<%=scalar($router->router_field) + 2%>"> -->
    <TD>
      <A HREF="<%=$p2%>edit/router.cgi?<%=$router->routernum%>"><%=$router->routername%></A>
    </TD>
  <!-- 
  <% foreach (sort { $a->part_router_field->name cmp $b->part_router_field->name } $router->router_field )  { %>
  <TR>
    <TD BGCOLOR="#cccccc" ALIGN="right"><%=$_->part_router_field->name%></TD>
    <TD BGCOLOR="#ffffff"><%=$_->value%></TD>
  </TR>
  <% } %>
  -->
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>

