%
%my $server = new FS::UI::Web::JSRPC 'FS::cust_event::process_reemail', $cgi;
%
<% $server->process %>
