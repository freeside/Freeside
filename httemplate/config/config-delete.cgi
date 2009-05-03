<%init>
die "access denied\n"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

$cgi->param('confnum') =~ /^(\d+)$/ or die "illegal or missing confnum";
my $confnum = $1;

my $conf = qsearchs('conf', {'confnum' => $confnum});
die "Configuration not found!" unless $conf;
$conf->delete;

my $redirect = popurl(2);
if ( $cgi->param('redirect') eq 'config_view_showagent' ) {
  $redirect .= 'config/config-view.cgi?showagent=1#'. $conf->name;
} elsif ( $cgi->param('redirect') eq 'config_view' ) {
  $redirect .= 'config/config-view.cgi';
} else {
  $redirect .= 'browse/agent.cgi';
}

</%init>
<% $cgi->redirect($redirect) %>
