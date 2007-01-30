<% include("/elements/header.html",'Routers', menubar('Main Menu'   => $p)) %>
%
%
%my @router = qsearch('router', {});
%my $p2 = popurl(2);
%
%
% if ($cgi->param('error')) { 

   <FONT SIZE="+1" COLOR="#ff0000">Error: <%$cgi->param('error')%></FONT>
   <BR><BR>
% } 
%
%my $hidecustomerrouters = 0;
%my $hideurl = '';
%if ($cgi->param('hidecustomerrouters') eq '1') {
%  $hidecustomerrouters = 1;
%  $cgi->param('hidecustomerrouters', 0);
%  $hideurl = '<A HREF="' . $cgi->self_url() . '">Show customer routers</A>';
%} else {
%  $hidecustomerrouters = 0;
%  $cgi->param('hidecustomerrouters', 1);
%  $hideurl = '<A HREF="' . $cgi->self_url() . '">Hide customer routers</A>';
%}
%


<A HREF="<%$p2%>edit/router.cgi">Add a new router</A>&nbsp;|&nbsp;<%$hideurl%>

<%table()%>
  <TR>
    <TD><B>Router name</B></TD>
    <TD><B>Address block(s)</B></TD>
  </TR>
% foreach my $router (sort {$a->routernum <=> $b->routernum} @router) {
%     next if $hidecustomerrouters && $router->svcnum;
%     my @addr_block = $router->addr_block;
%     if (scalar(@addr_block) == 0) {
%       push @addr_block, '&nbsp;';
%     }
%

  <TR>
    <TD ROWSPAN="<%scalar(@addr_block)+1%>">
      <A HREF="<%$p2%>edit/router.cgi?<%$router->routernum%>"><%$router->routername%></A>
    </TD>
  </TR>
% foreach my $block ( @addr_block ) { 

  <TR>
    <TD><%UNIVERSAL::isa($block, 'FS::addr_block') ? $block->NetAddr : '&nbsp;'%></TD>
  </TR>
% } 

  </TR>
% } 

</TABLE>
</BODY>
</HTML>
<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');
</%init>
