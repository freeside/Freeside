<% $conf->config_binary("logo.png", $agentnum) %>
<%init>

my $conf = new FS::Conf;

my $agentnum = $cgi->param('agentnum');

http_header('Content-Type' => 'image/png' );

</%init>
