<% $server->process %>

<%init>
my $server = FS::UI::Web::JSRPC->new('FS::part_export::cacti::process_graphs', $cgi);
</%init>

