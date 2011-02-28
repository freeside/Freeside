<% include('elements/svc_Common.html',
             'name'   => 'Port',
             'table'  => 'svc_port',
             'fields' => \@fields,
             'labels' => \%labels,
             #'post_url' => popurl(1). "process/svc_Common.html", #?
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my @fields = (
  { 'field' => 'serviceid',
    'type'  => 'select-torrus_serviceid',
    #'label' => 'Torrus serviceid',
  },
);

my %labels = ( 'svcnum'    => 'Service',
               'serviceid' => 'Torrus serviceid', );

</%init>

