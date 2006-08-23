%
%my $error = '';
%my $blocknum = $cgi->param('blocknum');
%my $routernum = $cgi->param('routernum');
%
%my $addr_block = qsearchs('addr_block', { blocknum => $blocknum });
%my $router = qsearchs('router', { routernum => $routernum });
%
%if($addr_block) {
%  if ($router) {
%    $error = $addr_block->allocate($router);
%  } else {
%    $error = "Cannot find router with routernum $routernum";
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

