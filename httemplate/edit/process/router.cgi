<% include('elements/process.html',
           'table'            => 'router',
           'viewall_dir'      => 'browse',
           'viewall_ext'      => 'cgi',
           'edit_ext'         => 'cgi',
           'process_m2m'      => { 'link_table'   => 'part_svc_router',
                                   'target_table' => 'part_svc',
                                 },
           'agent_virt'       => 1,
           'agent_null_right' => 'Engineering global configuration',
   )
%>
<%init>
my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Engineering configuration')
      || $curuser->access_right('Engineering global configuration');

</%init>
