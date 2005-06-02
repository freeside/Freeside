<%

my $server = new FS::UI::Web::JSRPC 'FS::cust_bill_event::process_reprint';
$server->process;

%>
