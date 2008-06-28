<% include( '../elements/process.html',
            'table'            => 'addr_block',
            'redirect'         => popurl(4). 'browse/addr_block.cgi?dummy=',
            'error_redirect'   => popurl(4). 'browse/addr_block.cgi?',
            'agent_virt'       => 1,
            'agent_null_right' => 'Engineering global configuration',

          )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied"
  unless $curuser->access_right('Engineering configuration')
      || $curuser->access_right('Engineering global configuration');

$cgi->param('routernum', 0)           # in FS::addr_block::check instead?
  unless $cgi->param('routernum');

</%init>
