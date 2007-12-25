<HTML><BODY>
%
%
%my $router;
%if ( $cgi->keywords ) {
%  my($query) = $cgi->keywords;
%  $query =~ /^(\d+)$/;
%  $router = qsearchs('router', { routernum => $1 }) 
%      or print $cgi->redirect(popurl(2)."browse/router.cgi") ;
%} else {
%  $router = new FS::router ( {
%    map { $_, scalar($cgi->param($_)) } fields('router')
%  } );
%}
%
%my $routernum = $router->routernum;
%my $action = $routernum ? 'Edit' : 'Add';
%
%print header("$action Router", menubar(
%  'Main Menu' => "$p",
%  'View all routers' => "${p}browse/router.cgi",
%));
%
%my $p3 = popurl(3);

<% include('/elements/error.html') %>

<FORM ACTION="<%popurl(1)%>process/router.cgi" METHOD=POST>
  <INPUT TYPE="hidden" NAME="table" VALUE="router">
  <INPUT TYPE="hidden" NAME="redirect_ok" VALUE="<%$p3%>/browse/router.cgi">
  <INPUT TYPE="hidden" NAME="redirect_error" VALUE="<%$p3%>/edit/router.cgi">
  <INPUT TYPE="hidden" NAME="routernum" VALUE="<%$routernum%>">
  <INPUT TYPE="hidden" NAME="svcnum" VALUE="<%$router->svcnum%>">
    Router #<%$routernum or "(NEW)"%>

<BR><BR>Name <INPUT TYPE="text" NAME="routername" SIZE=32 VALUE="<%$router->routername%>">

<BR><BR>
Custom fields:
<BR>
<%table() %>
%
%foreach my $field ($router->virtual_fields) {
%  print $router->pvf($field)->widget('HTML', 'edit', 
%        $router->getfield($field));
%}
%

</TABLE>
%
%unless ($router->svcnum) {
%

<BR><BR>Select the service types available on this router<BR>
%
%
%  foreach my $part_svc ( qsearch('part_svc', { svcdb    => 'svc_broadband',
%                                               disabled => '' }) ) {
%  

  <BR>
  <INPUT TYPE="checkbox" NAME="svcpart_<%$part_svc->svcpart%>"<%
      qsearchs('part_svc_router', { svcpart   => $part_svc->svcpart, 
                                    routernum => $routernum } ) ? ' CHECKED' : ''%> VALUE="ON">
  <A HREF="<%${p}%>edit/part_svc.cgi?<%$part_svc->svcpart%>">
    <%$part_svc->svcpart%>: <%$part_svc->svc%></A>
% } 
% } 


  <BR><BR><INPUT TYPE="submit" VALUE="Apply changes">
  </FORM>
</BODY></HTML>

