<%
my $server = new FS::UI::Web::JSRPC 'FS::rate::process';
$server->process;
%>
