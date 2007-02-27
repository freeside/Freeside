%
%
%my $conf=new FS::Conf;
%
%http_header('Content-Type' => 'application/x-unknown' );
%
%die "No configuration variable specified (bad URL)!" # umm
%  unless $cgi->keywords;
%my($query) = $cgi->keywords;
%$query =~  /^([\w -\)+-\/@;:?=[\]]+)$/;
%my $name = $1;
%
%http_header('Content-Disposition' => "attachment; filename=$name" );
% print $conf->config_binary($name);
