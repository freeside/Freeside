<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $server = new FS::UI::Web::JSRPC 'FS::cust_pkg::process_bulk_cust_pkg', $cgi;

</%init>
