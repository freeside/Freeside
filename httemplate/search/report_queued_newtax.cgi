<% include("/elements/header.html", "Queue Tax Report") %>
<% include("/elements/error.html") %>
% unless ($error) {
  <CENTER>
  Report queued.  Check the job queue for status.
  </CENTER>
% }
<% include("/elements/footer.html") %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $error = FS::tax_rate::queue_liability_report($cgi);

</%init>
