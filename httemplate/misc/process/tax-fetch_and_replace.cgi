<% $server->process %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $server = new FS::UI::Web::JSRPC 'FS::tax_rate::process_download_and_reload', $cgi; 

</%init>
