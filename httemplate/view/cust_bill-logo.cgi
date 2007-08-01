<% $conf->config_binary("logo$templatename.png") %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices')
      or $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;

my($query) = $cgi->keywords;
$query =~ /^([^\.\/]*)$/;
my $templatename = $1;
if ( $templatename && $conf->exists("logo_$templatename.png") ) {
  $templatename = "_$templatename";
} else {
  $templatename = '';
}

http_header('Content-Type' => 'image/png' );

</%init>
