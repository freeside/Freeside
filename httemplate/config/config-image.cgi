<% $conf->config_binary($name, $agentnum) %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;

http_header( 'Content-Type' => 'image/png' ); #just png for now

$cgi->param('key') =~ /^([-\w.]+)$/ or die "illegal config option";
my $name = $1;

my $agentnum = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
}

</%init>
