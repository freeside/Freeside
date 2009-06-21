<% include('/elements/header-popup.html', "Change Packages") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM ACTION="<% $p %>misc/process/bulk_change_pkg.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="query" VALUE="<% $cgi->keywords %>">
%  for my $param (qw(agentnum magic status classnum pkgpart)) {
<INPUT TYPE="hidden" NAME="<% $param %>" VALUE="<% $cgi->param($param) %>">
%  }
%
% foreach my $field (qw( setup last_bill bill adjourn susp expire cancel )) {
% 
  <INPUT TYPE="hidden" NAME="<% $field %>begin" VALUE="<% $cgi->param("${field}.begin") %>">
  <INPUT TYPE="hidden" NAME="<% $field %>beginning" VALUE="<% $cgi->param("${field}beginning") %>">
  <INPUT TYPE="hidden" NAME="<% $field %>end" VALUE="<% $cgi->param("${field}.end") %>">
  <INPUT TYPE="hidden" NAME="<% $field %>ending" VALUE="<% $cgi->param("${field}.ending") %>">
% }

<% ntable('#cccccc') %>

  <TR>
    <TD>New package: </TD>
    <TD><% include('/elements/select-table.html',
                     'table'          => 'part_pkg',
                     'name_col'       => 'pkg',
                     'empty_label'    => 'Select package',
                     'label_callback' => sub { $_[0]->pkg_comment },
                     'element_name'   => 'new_pkgpart',
                     'curr_value'     => ( $cgi->param('error')
                                           ? scalar($cgi->param('new_pkgpart'))
                                           : ''
                                         ),
                  )
        %>
    </TD>
  </TR>

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="Change packages">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages');

</%init>
