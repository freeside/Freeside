<% $response_xml %>\
<%init>

my $request_xml = $cgi->param('POSTDATA');

#warn $request_xml;

my $fsxmlrpc = new FS::XMLRPC;
my ($error, $response_xml) = $fsxmlrpc->serve($request_xml);

#warn $error;

http_header('Content-Type' => 'text/xml',
            'Content-Length' => length($response_xml));

</%init>
