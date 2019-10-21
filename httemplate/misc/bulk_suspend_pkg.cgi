<% include('/elements/header-popup.html', "Suspend Packages") %>

% if ( $cgi->param('error') ) {
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% }

<FORM ACTION="<% $p %>misc/process/bulk_suspend_pkg.cgi" METHOD=POST>

<& /elements/cust_pkg-search-form_input.html, $cgi &>

<% ntable('#cccccc') %>

% my $date_init = 0;
  <& /elements/tr-input-date-field.html, {
      'name'    => 'suspend_date',
      'value'   => $date,
      'label'   => mt("Suspend package on"),
      'format'  => $date_format,
  } &>
%   $date_init = 1;

  <& /elements/tr-select-reason.html,
       field          => 'suspend_reasonnum',
       reason_class   => 'S',
  &>

% if ( $FS::CurrentUser::CurrentUser->access_right('Unsuspend customer package')) {

  <& /elements/tr-input-date-field.html, {
      'name'    => 'suspend_resume_date',
      'value'   => '',
      'label'   => mt('Unsuspend on'),
      'format'  => $date_format,
      'noinit'  => $date_init,
  } &>
% }

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="Suspend Packages">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages');

#use Date::Parse qw(str2time);
#<table style="background-color: #cccccc; border-spacing: 2; width: 100%">

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my $date = time;

</%init>
