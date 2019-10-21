<% include('/elements/header-popup.html', "Cancel Packages") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM NAME     = "OneTrueForm"
      METHOD   = POST
      ACTION   = "<% $p %>misc/process/bulk_cancel_pkg.cgi"
      onSubmit = "document.OneTrueForm.submit.disabled=true;"
>

%# some false laziness w/search/cust_pkg.cgi

<INPUT TYPE="hidden" NAME="query" VALUE="<% $cgi->keywords |h %>">
% for my $param (
%   qw(
%     agentnum cust_status cust_main_salesnum salesnum custnum magic status
%     custom pkgbatch zip reasonnum
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
  <INPUT TYPE="hidden" NAME="<% $field %>_begin" VALUE="<% $cgi->param("${field}_begin") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>_beginning" VALUE="<% $cgi->param("${field}_beginning") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>_end" VALUE="<% $cgi->param("${field}_end") |h %>">
  <INPUT TYPE="hidden" NAME="<% $field %>_ending" VALUE="<% $cgi->param("${field}_ending") |h %>">
% }

<% ntable('#cccccc') %>

%#  <& /elements/tr-input-date-field.html, {
%#      'name'    => 'cancel_date',
%#      'label'   => mt("Cancel package on"),
%#      'format'  => $date_format,
%#  } &>
%#  <TR><TD></TD><TH>(Leave blank to cancel immediately)</TH></TR>

  <& /elements/tr-select-reason.html,
       field          => 'cancel_reasonnum',
       reason_class   => 'C',
  &>

</TABLE>

<BR>
<INPUT TYPE="submit" ID="submit" NAME="submit" VALUE="Cancel Packages">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages');

#use Date::Parse qw(str2time);
#<table style="background-color: #cccccc; border-spacing: 2; width: 100%">

my $conf = new FS::Conf;
#my $date_format = $conf->config('date_format') || '%m/%d/%Y';

</%init>
