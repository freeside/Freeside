<%
#my $server = new FS::rate::JSRPC;
#$server->process;
my $server = new FS::UI::Web::JSRPC 'FS::rate::process';
###wtf###$server->start_job;
$server->process;
%>
