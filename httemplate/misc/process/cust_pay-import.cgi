<% $server->process %>
<%init>
my $server = new FS::UI::Web::JSRPC 'FS::cust_pay::process_batch_import', $cgi; 
</%init>

