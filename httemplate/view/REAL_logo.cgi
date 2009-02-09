<% $conf->config_binary("logo.png", $agentnum) %>
<%init>

my $conf = new FS::Conf;

my $agentnum = '';
my @agentnums = $FS::CurrentUser::CurrentUser->agentnums;
if ( scalar(@agentnums) == 1 ) {
  $agentnum = $agentnums[0];
}

http_header('Content-Type' => 'image/png' );

</%init>
