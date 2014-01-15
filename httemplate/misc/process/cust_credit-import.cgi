<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $server =
  new FS::UI::Web::JSRPC 'FS::cust_credit::process_batch_import', $cgi;

</%init>
