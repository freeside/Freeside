%
%my $error = '';
%my $blocknum = $cgi->param('blocknum');
%
%my $addr_block = qsearchs('addr_block', { blocknum => $blocknum });
%
%if($addr_block) {
%  my $router = $addr_block->router;
%  if ($router) {
%    $error = $addr_block->deallocate($router);
%  } else {
%    $error = "Block is not allocated to a router";
%  }
%} else {
%  $error = "Cannot find block with blocknum $blocknum";
%}
%
%if ( $error ) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(4). "browse/addr_block.cgi?" . $cgi->query_string);
%} else { 
%  print $cgi->redirect(popurl(4). "browse/addr_block.cgi");
%}
%

<%init>

my $conf = new FS::Conf;
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

</%init>
