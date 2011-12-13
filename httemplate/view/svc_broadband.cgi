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

#my %labels = ();

$labels{'description'} = emt('Description');
$labels{'router'} = emt('Router');
$labels{'speed_down'} = emt('Download Speed');
$labels{'speed_up'} = emt('Upload Speed');
$labels{'ip_addr'} = emt('IP Address');
$labels{'usergroup'} = emt('RADIUS groups'); #?

$labels{'coordinates'} = 'Latitude/Longitude';

my @fields = (
  'description',
  { field => 'router', value => \&router },
  'speed_down',
  'speed_up',
  { field => 'ip_addr', value => \&ip_addr },
  { field => 'sectornum', value => \&sectornum },
  'mac_addr',
  #'latitude',
  #'longitude',
  { field => 'coordinates', value => \&coordinates },
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
  my $out = $ip_addr;
  $out .= ' (' . include('/elements/popup_link-ping.html', ip => $ip_addr) . ')'
    if $ip_addr;
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

sub coordinates {
  my $s = shift; #$svc_broadband
  return '' unless $s->latitude && $s->longitude;

  my $d = $s->description;
  unless ($d) {
    my $cust_pkg = $s->cust_svc->cust_pkg;
    $d = $cust_pkg->cust_main->name_short if $cust_pkg;
  }
  
  #'Latitude: '. $s->latitude. ', Longitude: '. $s->longitude. ' '.
  $s->latitude. ', '. $s->longitude. ' '.
    include('/elements/coord-links.html', $s->latitude, $s->longitude, $d);
}

</%init>
