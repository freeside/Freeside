<% include( 'elements/process.html',
              'table'       => 'agent',
              'viewall_dir' => 'browse',
              'viewall_ext' => 'cgi',
              'process_m2m' => { 'link_table'   => 'access_groupagent',
                                 'target_table' => 'access_group',
                               },
              'edit_ext'    => 'cgi',
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

</%init>
