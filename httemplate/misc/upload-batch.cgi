<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Process batches');

my $server =
  new FS::UI::Web::JSRPC 'FS::pay_batch::process_import_results', $cgi;

</%init>
