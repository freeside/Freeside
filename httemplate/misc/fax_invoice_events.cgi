<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Resend invoices');

my $server = new FS::UI::Web::JSRPC 'FS::cust_bill_event::process_refax', $cgi;

</%init>
