<% include('/elements/header.html', 'Routers') %>

<% include('/elements/error.html') %>

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

<A HREF="<%$p2%>edit/router.cgi">Add a new router</A>&nbsp;|&nbsp;<%$hideurl%>

<% include('/elements/table-grid.html') %>
% my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor = '';

  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc">Router name</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Address block(s)</TH>
  </TR>

% foreach my $router (sort {$a->routernum <=> $b->routernum} @router) {
%     next if $hidecustomerrouters && $router->svcnum;
%     my @addr_block = $router->addr_block;
%     if (scalar(@addr_block) == 0) {
%       push @addr_block, '&nbsp;';
%     }
%
%    if ( $bgcolor eq $bgcolor1 ) {
%      $bgcolor = $bgcolor2;
%    } else {
%      $bgcolor = $bgcolor1;
%    }

  <TR>

    <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <A HREF="<%$p2%>edit/router.cgi?<%$router->routernum%>"><%$router->routername%></A>
    </TD>

    <TD CLASS="inv" BGCOLOR="<% $bgcolor %>">
      <TABLE CLASS="inv" CELLSPACING=0 CELLPADDING=0>

%       foreach my $block ( @addr_block ) { 

          <TR>
            <TD><%UNIVERSAL::isa($block, 'FS::addr_block') ? $block->NetAddr : '&nbsp;'%></TD>
          </TR>
%       } 
      </TABLE>
    </TD>

  </TR>

% } 

</TABLE>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my @router = qsearch('router', {});
my $p2 = popurl(2);

</%init>
