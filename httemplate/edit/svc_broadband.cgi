<% include('elements/svc_Common.html',
     'post_url'             => popurl(1). 'process/svc_broadband.cgi',
     'name'                 => 'broadband service',
     'table'                => 'svc_broadband',
     'labels'               => { 'svcnum'       => 'Service',
                                 'description'  => 'Description',
                                 'ip_addr'      => 'IP address',
                                 'speed_down'   => 'Download speed',
                                 'speed_up'     => 'Upload speed',
                                 'blocknum'     => 'Router/Block',
                                 'block_label'  => 'Router/Block',
                                 'mac_addr'     => 'MAC address',
                                 'latitude'     => 'Latitude',
                                 'longitude'    => 'Longitude',
                                 'altitude'     => 'Altitude',
                                 'vlan_profile' => 'VLAN profile',
                                 'performance_profile' => 'Performance profile',
                                 'authkey'      => 'Authentication key',
                               },
     'fields'               => \@fields, 
     'field_callback'       => $callback,
     'dummy'                => $cgi->query_string,
     )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

# If it's stupid but it works, it's still stupid.
#  -Kristian

my $conf = new FS::Conf;

my @fields = (
  qw( description ip_addr speed_down speed_up blocknum ),
  { field=>'block_label', type=>'fixed' },
  qw( mac_addr latitude longitude altitude vlan_profile performance_profile authkey )
);

my $fixedblock = '';

my $callback = sub {
  my ($cgi, $object, $fieldref) = @_;

  my $svcpart = $object->svcnum ? $object->cust_svc->svcpart
                                : $cgi->param('svcpart');

  my $part_svc = qsearchs( 'part_svc', { svcpart => $svcpart } );
  die "No part_svc entry!" unless $part_svc;

  my $columndef = $part_svc->part_svc_column($fieldref->{'field'});
  if ($columndef->columnflag eq 'F') {
    $fieldref->{'type'} = 'fixed';
    $fieldref->{'value'} = $columndef->columnvalue;
    $fixedblock = $fieldref->{value}
      if $fieldref->{field} eq 'blocknum';
  }

  if ($object->svcnum) { 

    $fieldref->{type} = 'hidden'
      if $fieldref->{field} eq 'blocknum';
      
    $fieldref->{value} = $object->addr_block->label
      if $fieldref->{field} eq 'block_label';

  } else { 

    if ($fieldref->{field} eq 'block_label') {
      if ($fixedblock) {
        $object->blocknum($fixedblock);
        $fieldref->{value} = $object->addr_block->label;
      }else{
        $fieldref->{type} = 'hidden';
      }
    }

    if ($fieldref->{field} eq 'blocknum') {
      if ( $fixedblock or $conf->exists('auto_router') ) {
        $fieldref->{type} = 'hidden';
        $fieldref->{value} = $fixedblock;
        return;
      }

      my $cust_pkg = qsearchs( 'cust_pkg', {pkgnum => $cgi->param('pkgnum')} );
      die "No cust_pkg entry!" unless $cust_pkg;

      $object->svcpart($part_svc->svcpart);
      my @addr_block =
        grep {  ! $_->agentnum
               || $cust_pkg->cust_main->agentnum == $_->agentnum
               && $FS::CurrentUser::CurrentUser->agentnum($_->agentnum)
             }
        map { $_->addr_block } $object->allowed_routers;
      my @options = map { $_->blocknum } 
                    sort { $a->label cmp $b->label } @addr_block;
      my %option_labels = map { ( $_->blocknum => $_->label ) } @addr_block;
      $fieldref->{type}    = 'select';
      $fieldref->{options} = \@options;
      $fieldref->{labels}  = \%option_labels;
    }

  }
}; 

</%init>
