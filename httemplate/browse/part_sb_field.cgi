<%= header('svc_broadband extended fields', menubar('Main Menu'   => $p)) %>
<%

my @psf = qsearch('part_sb_field', {});
my $block;
my $p2 = popurl(2);

%>

<% if ($cgi->param('error')) { %>
   <FONT SIZE="+1" COLOR="#ff0000">Error: <%=$cgi->param('error')%></FONT>
   <BR><BR>
<% } %>

<A HREF="<%=$p2%>edit/part_sb_field.cgi"><I>Add a new field</I></A><BR><BR>

<%=table()%>
<TH><TD>Field name</TD><TD>Service type</TD></TH>
<% foreach $psf (sort {$a->name cmp $b->name} @psf) { %>
  <TR>
    <TD></TD>
    <TD>
      <A HREF="<%=$p2%>edit/part_sb_field.cgi?<%=$psf->sbfieldpart%>">
        <%=$psf->name%></A></TD>
    <TD><%=$psf->part_svc->svc%></TD>
  </TR>
<% } %>
</TABLE>
</BODY>
</HTML>

