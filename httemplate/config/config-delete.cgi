<%init>
die "access denied\n"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

die "No configuration item specified (bad URL)!" unless $cgi->keywords;
my ($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $confnum = $1;

my $conf = qsearchs('conf', {'confnum' => $confnum});
die "Configuration not found!" unless $conf;
$conf->delete;

</%init>
<% $cgi->redirect(popurl(2) . "browse/agent.cgi") %>
