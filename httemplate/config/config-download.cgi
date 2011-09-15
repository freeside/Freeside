<%init>
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $agentnum;
if ($cgi->param('agentnum') =~ /^(\d+)$/) {
  $agentnum = $1;
}

http_header('Content-Type' => 'application/x-unknown' );

die "No configuration variable specified (bad URL)!" # umm
  unless $cgi->param('key');
$cgi->param('key') =~  /^([-\w.]+)$/;
my $name = $1;

my $agentnum;
if ($cgi->param('agentnum') =~ /^(\d+)$/) {
  $agentnum = $1;
}

my $locale = '';
if ($cgi->param('locale') =~ /^(\w+)$/) {
  $locale = $1;
}
my $conf=new FS::Conf { 'locale' => $locale };

http_header('Content-Disposition' => "attachment; filename=$name" );
print $conf->config_binary($name, $agentnum);
</%init>
