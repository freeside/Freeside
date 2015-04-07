<% $server->process %>

<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my $server = FS::UI::Web::JSRPC->new('FS::part_export::cacti::process_graphs', $cgi);
</%init>

