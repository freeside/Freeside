<%

my($query) = $cgi->keywords;
$query =~ /^([^\.\/]*)$/;
my $templatename = $1;
if ( $templatename && $conf->exists("${logo}_$templatename.png") ) {
  $templatename = "_$templatename";
} else {
  $templatename = '';
}

my $conf = new FS::Conf;

http_header('Content-Type' => 'image/png' );
%><%= $conf->config_binary("logo$templatename.png") %>
