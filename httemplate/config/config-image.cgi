<% $logo %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

http_header( 'Content-Type' => 'image/png' ); #just png for now

$cgi->param('key') =~ /^([-\w.]+)$/ or die "illegal config option";
my $name = $1;

my $agentnum = '';
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $agentnum = $1;
}

my $locale = '';
if ( $cgi->param('locale') =~ /^(\w+)$/ ) {
  $locale = $1;
}

my $conf = new FS::Conf { 'locale' => $locale };

my $logo = $conf->config_binary($name, $agentnum);
$logo = eps2png($logo) if $name =~ /\.eps$/i;

</%init>
