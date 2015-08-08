<& elements/svc_Common.html,
  'table'        => 'svc_circuit',
  'labels'       => \%labels,
  'fields'       => \@fields,
  'html_foot'    => sub { $self->call_method('.foot', @_) },
&>
<%method .foot>
% my $svc_circuit = shift;
% my $link = [ 'svc_phone.cgi?', 'svcnum' ];
% if ( FS::svc_phone->count('circuit_svcnum = '.$svc_circuit->svcnum) ) {
<& /search/elements/search.html,

  'title' => 'Provisioned phone services',
  'name_singular' => 'phone number',
  'query' => { 'table'      => 'svc_phone',
               'hashref'    => { 'circuit_svcnum' => $svc_circuit->svcnum },
               'addl_from'  => ' LEFT JOIN cust_svc USING (svcnum)'.
                               ' LEFT JOIN part_svc USING (svcpart)',
               'select'     => 'svc_phone.*, part_svc.*',
             },
  'count_query' => 'SELECT COUNT(*) FROM svc_phone WHERE circuit_svcnum = '.
                    $svc_circuit->svcnum,
  'header' => [ '#', 'Service', 'Phone number', ],
  'fields' => [ 'svcnum', 'svc', 'phonenum' ],
  'links'  => [ $link, $link, $link ],
  'align'  => 'rlr',

  'html_form' => '<SPAN CLASS="fsinnerbox-title">Phone services</SPAN>',
  'nohtmlheader' => 1,
  'disable_total' => 1,
  'disable_maxselect' => 1,
  'really_disable_download' => 1,
&>
  <BR>
% }
</%method>
<%init>

my @fields = (
  'circuit_id',
  { field     => 'providernum',
    type      => 'select-table',
    table     => 'circuit_provider',
    name_col  => 'provider',
  },
  { field     => 'typenum',
    type      => 'select-table',
    table     => 'circuit_type',
    name_col  => 'typename',
  },
  { field     => 'termnum',
    type      => 'select-table',
    table     => 'circuit_termination',
    name_col  => 'termination',
  },
  qw( vendor_qual_id vendor_order_id vendor_order_type vendor_order_status ),
  { field     => 'desired_due_date', type => 'date' },
  { field     => 'due_date', type => 'date' },
  'endpoint_ip_addr',
  { field     => 'endpoint_mac_addr', type => 'mac_addr' },
);


my %labels = (
  circuit_id          => 'Circuit ID',
  providernum         => 'Provider',
  typenum             => 'Circuit type',
  termnum             => 'Termination',
  vendor_qual_id      => 'Qualification ID',
  vendor_order_id     => 'Order ID',
  vendor_order_type   => 'Order type',
  vendor_order_status => 'Order status',
  desired_due_date    => 'Desired due date',
  due_date            => 'Due date',
  endpoint_ip_addr    => 'Endpoint IP address',
  endpoint_mac_addr   => 'MAC address',
);

my $self = $m->request_comp;
</%init>
