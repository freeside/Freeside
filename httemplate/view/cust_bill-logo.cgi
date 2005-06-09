<%

my($query) = $cgi->keywords;
$query =~ /^([^\.\/]*)$/;
my $templatename = $1;
$templatename = "_$templatename" if $templatename;

my $conf = new FS::Conf;
http_header('Content-Type' => 'image/png' );

http_header('Content-Type' => 'image/png' );
%><%= $conf->config_binary("logo$templatename.png") %>
