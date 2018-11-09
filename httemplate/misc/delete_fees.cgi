<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Delete fees');

my $server = new FS::UI::Web::JSRPC 'FS::cust_event_fee::process_delete', $cgi; 

</%init>
