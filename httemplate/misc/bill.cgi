<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bill customer now');
my $server = FS::UI::Web::JSRPC->new('FS::cust_main::process_bill_and_collect', $cgi);
</%init>

