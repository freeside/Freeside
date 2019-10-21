<% include('/elements/header-popup.html', "Unsuspend Packages") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM ACTION="<% $p %>misc/process/bulk_unsuspend_pkg.cgi" METHOD=POST>

<& /elements/cust_pkg-search-form_input.html, $cgi &>

<% ntable('#cccccc') %>

  <TR>
    <TD><INPUT TYPE="checkbox" NAME="confirm"></TD>
    <TD>Confirm Unsuspend Packages</TD>
  </TR>

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="Unsuspend Packages">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages');

</%init>
