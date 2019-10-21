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

<& /elements/cust_pkg-search-form_input.html, $cgi &>

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
