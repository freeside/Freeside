<& elements/svc_Common.html,
  table   => 'svc_broadband',
  labels  => \%labels,
  fields  => \@fields,
&>
<%init>

my $conf = FS::Conf->new;
my $fields = FS::svc_broadband->table_info->{'fields'};
my %labels = map { $_ => ( ref($fields->{$_}) 
                            ? $fields->{$_}{'label'} 
                            : $fields->{$_}
                          );
                 } keys %$fields;

$labels{'router'} = emt('Router');
$labels{'usergroup'} = emt('RADIUS groups'); #?

my @fields = (
  'description',
  { field => 'router', value => \&router },
  'speed_down',
  'speed_up',
  { field => 'ip_addr', value => \&ip_addr },
  { field => 'sectornum', value => \&sectornum },
  'mac_addr',
  'latitude',
  'longitude',
  'altitude',
  'vlan_profile',
  'authkey',
  'plan_id',
);

push @fields,
  { field => 'usergroup', value => \&usergroup }
  if $conf->exists('svc_broadband-radius');

sub router {
  my $svc = shift;
  my $addr_block = $svc->addr_block or return '';
  my $router = $addr_block->router or return '';
  $router->routernum . ': ' . $router->routername;
}

sub ip_addr {
  my $svc = shift;
  my $ip_addr = $svc->ip_addr;
  my $out = $ip_addr . ' (' . 
    include('/elements/popup_link-ping.html', ip => $ip_addr) . ')';
  if ( my $addr_block = $svc->addr_block ) {
    $out .= '<br>Netmask: ' . $addr_block->NetAddr->mask .
            '<br>Gateway: ' . $addr_block->ip_gateway;
  }
  $out;
}

sub usergroup {
  my $svc = shift;
  my $usergroup = $svc->usergroup;
  join('<BR>', $svc->radius_groups('long_description'));
}

sub sectornum {
  my $svc_broadband = shift;
  return '' unless $svc_broadband->sectornum;
  my $tower_sector = $svc_broadband->tower_sector;
  my $link = $tower_sector->ip_addr
               ? '<A HREF="http://'. $tower_sector->ip_addr. '">'
               : '';

  $link .  $tower_sector->description. ( $link ? '</A>' : '');
}

</%init>
