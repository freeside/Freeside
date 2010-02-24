<% include('/elements/header-popup.html', "Increment Bill Date") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM ACTION="<% $p %>misc/process/bulk_pkg_increment_bill.cgi" METHOD=POST>

%# some false laziness w/search/cust_pkg.cgi

<INPUT TYPE="hidden" NAME="query" VALUE="<% $cgi->keywords |h %>">
%  for my $param (qw(agentnum custnum magic status classnum custom censustract)) {
<INPUT TYPE="hidden" NAME="<% $param %>" VALUE="<% $cgi->param($param) |h %>">
%  }
%
% foreach my $pkgpart ($cgi->param('pkgpart')) {
<INPUT TYPE="hidden" NAME="pkgpart" VALUE="<% $pkgpart |h %>">
% }
%
% foreach my $field (qw( setup last_bill bill adjourn susp expire cancel )) {
% 
  <INPUT TYPE="hidden" NAME="<% $field %>begin" VALUE="<% $cgi->param("${field}.begin") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>beginning" VALUE="<% $cgi->param("${field}beginning") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>end" VALUE="<% $cgi->param("${field}.end") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>ending" VALUE="<% $cgi->param("${field}.ending") |h %>">
% }

<% ntable('#cccccc') %>

  <TR>
    <TD>Days to increment: </TD>
    <TD><INPUT type="text" name="days"></TD>
  </TR>

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="Increment bill date">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages');

</%init>
