<%

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
%><%= $conf->config_binary("logo$templatename.png") %>
