%
%
%my $error = '';
%my $ip_gateway = $cgi->param('ip_gateway');
%my $ip_netmask = $cgi->param('ip_netmask');
%
%my $new = new FS::addr_block {
%    ip_gateway => $ip_gateway,
%    ip_netmask => $ip_netmask,
%    routernum  => 0 };
%
%$error = $new->insert;
%
%if ( $error ) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(4). "browse/addr_block.cgi?". $cgi->query_string );
%} else { 
%  print $cgi->redirect(popurl(4). "browse/addr_block.cgi");
%} 
%

<%init>

my $conf = new FS::Conf;
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

</%init>
