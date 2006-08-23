%
%
%  my $request_xml = $cgi->param('POSTDATA');
%
%  #$r->log_error($request_xml);
%
%  my $fsxmlrpc = new FS::XMLRPC;
%  my ($error, $response_xml) = $fsxmlrpc->serve($request_xml);
%  
%  #$r->log_error($error) if $error;
%
%  http_header('Content-Type' => 'text/xml',
%              'Content-Length' => length($response_xml));
%
%  print $response_xml;
%
%

