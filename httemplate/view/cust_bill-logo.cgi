<%

##untaint invnum
#my($query) = $cgi->keywords;
#$query =~ /^((.+)-)?(\d+)$/;
#my $templatename = $2;
#my $invnum = $3;

my $templatename = '';

my $conf = new FS::Conf;
http_header('Content-Type' => 'image/png' );

http_header('Content-Type' => 'image/png' );
%><%= $conf->config_binary("logo$templatename.png") %>
