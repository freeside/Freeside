<%
my $server = new FS::UI::Web::JSRPC 'FS::part_svc::process';
$server->process;
%>
