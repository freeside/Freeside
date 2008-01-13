<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $server = new FS::UI::Web::JSRPC 'FS::part_svc::process_bulk_cust_svc', $cgi;

</%init>
