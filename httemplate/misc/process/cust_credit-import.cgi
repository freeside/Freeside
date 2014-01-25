<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my %arg = $cgi->param('arg');
$arg{_date} = parse_datetime( $arg{_date} )
  if $arg{_date} && $arg{_date} =~ /\D/;
$cgi->param('arg', %arg );

my $server =
  new FS::UI::Web::JSRPC 'FS::cust_credit::process_batch_import', $cgi;

</%init>
