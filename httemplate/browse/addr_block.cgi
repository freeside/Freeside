<% include('/elements/header.html', 'Address Blocks') %>

<% include('/elements/error.html') %>

<% include('/elements/table-grid.html') %>
% my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor = '';

  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc">Address block(s)</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Router</TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">Action(s)</TH>
  </TR>

% foreach $block (sort {$a->NetAddr cmp $b->NetAddr} @addr_block) { 
%    if ( $bgcolor eq $bgcolor1 ) {
%      $bgcolor = $bgcolor2;
%    } else {
%      $bgcolor = $bgcolor1;
%    }

    <TR>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><%$block->NetAddr%></TD>

%   if (my $router = $block->router) { 
%
%     if (scalar($block->svc_broadband) == 0) { 

        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <%$router->routername%>
        </TD>
        <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
          <FORM ACTION="<%$path%>/deallocate.cgi" METHOD="POST">
            <INPUT TYPE="hidden" NAME="blocknum" VALUE="<%$block->blocknum%>">
            <INPUT TYPE="submit" NAME="submit" VALUE="Deallocate">
          </FORM>
        </TD>
%     } else { 

        <TD COLSPAN="2" CLASS="grid" BGCOLOR="<% $bgcolor %>">
        <%$router->routername%>
        </TD>
%     } 
%
%   } else { 

      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
        <FORM ACTION="<%$path%>/allocate.cgi" METHOD="POST">
          <INPUT TYPE="hidden" NAME="blocknum" VALUE="<%$block->blocknum%>">
          <SELECT NAME="routernum" SIZE="1">
%           foreach (@router) { 
              <OPTION VALUE="<%$_->routernum %>"><%$_->routername%></OPTION>
%           } 
          </SELECT>
          <INPUT TYPE="submit" NAME="submit" VALUE="Allocate">
        </FORM>
      </TD>
      <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
        <FORM ACTION="<%$path%>/split.cgi" METHOD="POST">
          <INPUT TYPE="hidden" NAME="blocknum" VALUE="<%$block->blocknum%>">
          <INPUT TYPE="submit" NAME="submit" VALUE="Split">
        </FORM>
      </TD>

%   }

  </TR>
% } 

</TABLE>

<BR><BR>
<FORM ACTION="<%$path%>/add.cgi" METHOD="POST">
Gateway/Netmask: 
<INPUT TYPE="text" NAME="ip_gateway" SIZE="15">/<INPUT TYPE="text" NAME="ip_netmask" SIZE="2">
<INPUT TYPE="submit" NAME="submit" VALUE="Add">

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my @addr_block = qsearch('addr_block', {});
my @router = qsearch('router', {});
my $block;
my $p2 = popurl(2);
my $path = $p2 . "edit/process/addr_block";

</%init>
