<% include('/elements/header-popup.html', "Change Packages") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM ACTION="<% $p %>misc/process/bulk_change_pkg.cgi" METHOD=POST>

%# some false laziness w/search/cust_pkg.cgi

<INPUT TYPE="hidden" NAME="query" VALUE="<% $cgi->keywords |h %>">
% for my $param (
%   qw(
%     agentnum cust_status cust_main_salesnum salesnum custnum magic status
%     custom pkgbatch zip
%     477part 477rownum date
%     report_option
%   ),
%   grep { /^location_\w+$/ || /^report_option_any/ } $cgi->param
% ) {
  <INPUT TYPE="hidden" NAME="<% $param %>" VALUE="<% $cgi->param($param) |h %>">
% }
%
% for my $param (qw( censustract censustract2 ) ) {
%   next unless grep { $_ eq $param } $cgi->param;
  <INPUT TYPE="hidden" NAME="<% $param %>" VALUE="<% $cgi->param($param) |h %>">
% }
%
% for my $param (qw( pkgpart classnum refnum towernum )) {
%   foreach my $value ($cgi->param($param)) {
      <INPUT TYPE="hidden" NAME="<% $param %>" VALUE="<% $value |h %>">
%   }
% }
%
% foreach my $field (qw( setup last_bill bill adjourn susp expire contract_end change_date cancel active )) {
% 
  <INPUT TYPE="hidden" NAME="<% $field %>_null" VALUE="<% $cgi->param("${field}_null") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>begin" VALUE="<% $cgi->param("${field}.begin") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>beginning" VALUE="<% $cgi->param("${field}beginning") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>end" VALUE="<% $cgi->param("${field}.end") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>ending" VALUE="<% $cgi->param("${field}.ending") |h %>">
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
