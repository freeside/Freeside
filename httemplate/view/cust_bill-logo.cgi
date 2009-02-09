<% $conf->config_binary("logo$templatename.png", $agentnum) %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices')
      or $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;

my $templatename;
my $agentnum = '';
if ( $cgi->param('invnum') ) {
  $templatename = $cgi->param('templatename');
  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $cgi->param('invnum') } )
    or die 'unknown invnum';
  $agentnum = $cust_bill->cust_main->agentnum;
} else {
  my($query) = $cgi->keywords;
  $query =~ /^([^\.\/]*)$/ or die 'illegal query';
  $templatename = $1;
}

if ( $templatename && $conf->exists("logo_$templatename.png") ) {
  $templatename = "_$templatename";
} else {
  $templatename = '';
}

http_header('Content-Type' => 'image/png' );

</%init>
