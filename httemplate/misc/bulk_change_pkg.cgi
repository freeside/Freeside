<% include('/elements/header-popup.html', "Change Packages") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM ACTION="<% $p %>misc/process/bulk_change_pkg.cgi" METHOD=POST>

<& /elements/cust_pkg-search-form_input.html, $cgi &>

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
