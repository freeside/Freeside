<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $server =
   new FS::UI::Web::JSRPC 'FS::tax_rate::queue_liability_report', $cgi;

</%init>
