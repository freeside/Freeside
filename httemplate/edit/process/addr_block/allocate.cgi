<% include( '../elements/process.html',
            'table'          => 'addr_block',
            'copy_on_empty'  => [ fields 'addr_block' ],
            'error_redirect' => popurl(3). 'allocate.html?',
            'popup_reload'   => 'Block allocated',
          )
%>
<%init>

my $conf = new FS::Conf;
my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied"
  unless $curuser->access_right('Broadband configuration')
      || $curuser->access_right('Broadband global configuration');

</%init>
