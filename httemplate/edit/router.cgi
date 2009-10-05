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
                        { 'field'=>'svcnum',     'type'=>'hidden' },
                      ],
     'error_callback' => $callback,
     'edit_callback'  => $callback,
     'new_callback'   => $callback,
     'html_table_bottom' => $html_table_bottom,
   )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Broadband configuration')
    || $curuser->access_right('Broadband global configuration');

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

my $html_table_bottom = sub {
  my $router = shift;
  foreach my $field ($router->virtual_fields) {
    $html .= $router->pvf($field)->widget('HTML', 'edit', $router->get($field));
  }
  $html;
};
</%init>
