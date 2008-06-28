<% include('elements/svc_Common.html', 'table' => 'svc_broadband') %>
<%init>
my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Provision customer service'); #something else more specific?

</%init>
