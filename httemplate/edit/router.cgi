<HTML><BODY>

<%

my $router;
if ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $router = qsearchs('router', { routernum => $1 }) 
      or print $cgi->redirect(popurl(2)."browse/router.cgi") ;
} else {
  $router = new FS::router ( {
    map { $_, scalar($cgi->param($_)) } fields('router')
  } );
}

my $routernum = $router->routernum;
my $action = $routernum ? 'Edit' : 'Add';
my $hashref = $router->hashref;

print header("$action Router", menubar(
  'Main Menu' => "$p",
  'View all routers' => "${p}browse/router.cgi",
));

if($cgi->param('error')) {
%> <FONT SIZE="+1" COLOR="#ff0000">Error: <%=$cgi->param('error')%></FONT>
<% } %>

<FORM ACTION="<%=popurl(1)%>process/router.cgi" METHOD=POST>
  <INPUT TYPE="hidden" NAME="routernum" VALUE="<%=$routernum%>">
    Router #<%=$routernum or "(NEW)"%>

<BR><BR>Name <INPUT TYPE="text" NAME="routername" SIZE=32 VALUE="<%=$hashref->{routername}%>">
<%=table() %>

<%
# I know, I know.  Massive false laziness with edit/svc_broadband.cgi.  But 
# Kristian won't let me generalize the custom field mechanism to every table in 
# the database, so this is what we get.  <snarl>
# -- MW

my @part_router_field = qsearch('part_router_field', { });
my %rf = map { $_->part_router_field->name, $_->value } $router->router_field;
foreach (sort { $a->name cmp $b->name } @part_router_field) {
  %>
  <TR>
    <TD ALIGN="right"><%=$_->name%></TD>
    <TD><%
  if(my @opts = $_->list_values) {
    %>  <SELECT NAME="rf_<%=$_->routerfieldpart%>" SIZE="1">
          <%
    foreach $opt (@opts) {
      %>  <OPTION VALUE="<%=$opt%>"<%=($opt eq $rf{$_->name}) 
              ? ' SELECTED' : ''%>>
            <%=$opt%>
	  </OPTION>
   <% } %>
	</SELECT>
 <% } else { %>
        <INPUT NAME="rf_<%=$_->routerfieldpart%>"
        VALUE="<%=$rf{$_->name}%>"
        <%=$_->length ? 'SIZE="'.$_->length.'"' : ''%>>
  <% } %></TD>
  </TR>
<% } %>
</TABLE>



<BR><BR>Select the service types available on this router<BR>
<%

foreach my $part_svc ( qsearch('part_svc', { svcdb    => 'svc_broadband',
                                             disabled => '' }) ) {
  %>
  <BR>
  <INPUT TYPE="checkbox" NAME="svcpart_<%=$part_svc->svcpart%>"<%=
      qsearchs('part_svc_router', { svcpart   => $part_svc->svcpart, 
                                    routernum => $routernum } ) ? 'CHECKED' : ''%> VALUE="ON">
  <A HREF="<%=${p}%>edit/part_svc.cgi?<%=$part_svc->svcpart%>">
    <%=$part_svc->svcpart%>: <%=$part_svc->svc%></A>
  <% } %>

  <BR><BR><INPUT TYPE="submit" VALUE="Apply changes">
  </FORM>
</BODY></HTML>

