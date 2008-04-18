<% include( '../elements/process.html',
            'table'          => 'addr_block',
            'copy_on_empty'  => [ fields 'addr_block' ],
            'error_redirect' => popurl(3). 'allocate.html?',
            'popup_reload'   => 'Block allocated',
          )
%>
<%init>

my $conf = new FS::Conf;
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

</%init>
