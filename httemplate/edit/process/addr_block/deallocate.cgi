<% include( '../elements/process.html',
            'table'            => 'addr_block',
            'copy_on_empty'    => [ grep { $_ ne 'routernum' }
                                    fields 'addr_block' ],
            'redirect'         => popurl(4). 'browse/addr_block.cgi?',
            'error_redirect'   => popurl(4). 'browse/addr_block.cgi?',
            'agent_virt'       => 1,
            'agent_null_right' => 'Engineering global configuration',
          )
%>
<%init>

my $conf = new FS::Conf;
my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied"
  unless $curuser->access_right('Engineering configuration')
      || $curuser->access_right('Engineering global configuration');

$cgi->param('routernum', 0);  # just to be explicit about what we are doing
</%init>
