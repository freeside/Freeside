<% $server->process %>
<%init>
my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied"
  unless $curuser->access_right([
    'Edit FCC report configuration',
    'Edit FCC report configuration for all agents',
  ]);

my $server = FS::UI::Web::JSRPC->new(
  'FS::deploy_zone::process_block_lookup', $cgi
);
</%init>
