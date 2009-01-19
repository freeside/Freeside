<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Resend invoices');

my $server = new FS::UI::Web::JSRPC 'FS::tax_rate::process_batch_import', $cgi; 

</%init>
