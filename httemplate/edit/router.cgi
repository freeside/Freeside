<% include('elements/edit.html',
     'post_url'    => popurl(1).'process/router.cgi',
     'name'        => 'router',
     'table'       => 'router',
     'viewall_url' => "${p}browse/router.cgi",
     'labels'      => { 'routernum'  => 'Router',
                        'routername' => 'Name',
                        'svc_part'   => 'Service',
                      },
     'fields'      => [
                        { 'field'=>'routername', 'type'=>'text', 'size'=>32 },
                        { 'field'=>'agentnum',   'type'=>'select-agent' },
                      ],
     'error_callback' => $callback,
     'edit_callback'  => $callback,
     'new_callback'   => $callback,
   )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Engineering configuration')
    || $curuser->access_right('Engineering global configuration');

my $callback = sub {
  my ($cgi, $object, $fields) = (shift, shift, shift);
  unless ($object->svcnum) {
    push @{$fields},
      { 'type'          => 'tablebreak-tr-title',
        'value'         => 'Select the service types available on this router',
      },
      { 'field'         => 'svc_part',
        'type'          => 'checkboxes-table',
        'target_table'  => 'part_svc',
        'link_table'    => 'part_svc_router',
        'name_col'      => 'svc',
        'hashref'       => { 'svcdb' => 'svc_broadband', 'disabled' => '' },
      };
  }
};

</%init>
