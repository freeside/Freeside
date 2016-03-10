<& elements/svc_Common.html,
  'table'       => 'svc_fiber',
  'fields'      => \@fields,
  'labels'      => \%labels,
  'edit_url'    => $fsurl.'edit/svc_fiber.html?',
&>
<%init>

my @fields = (
  'circuit_id',
  { field     => 'oltnum',
    type      => 'select-table',
    table     => 'fiber_olt',
    name_col  => 'description',
  },
  'shelf',
  'card',
  'olt_port',
  'ont_id',
  'ont_description',
  'ont_serial',
  'ont_port',
  'vlan',
  'signal',
  'speed_down',
  'speed_up',
  'ont_install',
);

my $fields = FS::svc_fiber->table_info->{'fields'};
my %labels = map { $_ => $fields->{$_}{'label'} } keys %$fields;

$labels{'ont_description'} = 'ONT model';

</%init>
