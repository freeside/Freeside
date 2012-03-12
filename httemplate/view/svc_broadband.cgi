<& elements/svc_Common.html,
  table   => 'svc_broadband',
  labels  => \%labels,
  fields  => \@fields,
  svc_callback => \&svc_callback,
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
$labels{'speed_down'} = emt('Download Speed');
$labels{'speed_up'} = emt('Upload Speed');
$labels{'ip_addr'} = emt('IP Address');
$labels{'usergroup'} = emt('RADIUS groups'); #?

$labels{'coordinates'} = 'Latitude/Longitude';

my @fields = (
  'description',
  { field => 'routernum', value => \&router },
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
  my $router = $svc->router or return '';
  my $block = $svc->addr_block;
  $block = '; '.$block->cidr if $block;
  $router->routernum . ': ' . $router->routername . $block
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
  my $agentnum;
  unless ($d) {
    if ( my $cust_pkg = $s->cust_svc->cust_pkg ) {
      $d = $cust_pkg->cust_main->name_short;
      $agentnum = $cust_pkg->cust_main->agentnum;
    }
  }
  
  #'Latitude: '. $s->latitude. ', Longitude: '. $s->longitude. ' '.
  $s->latitude. ', '. $s->longitude. ' '.
    include('/elements/coord-links.html', 
      $s->latitude,
      $s->longitude,
      $d,
      $agentnum
    );
}

sub svc_callback {
  # trying to move to the callback style
  my ($cgi, $svc_x, $part_svc, $cust_pkg, $fields, $opt) = @_;
  # again, we assume at most one of these exports per part_svc
  my ($nas_export) = $part_svc->part_export('broadband_nas');
  if ( $nas_export ) {
    my $nas = qsearchs('nas', { 'svcnum' => $svc_x->svcnum });
    if ( $nas ) {
      $svc_x->set($_, $nas->$_) foreach (fields('nas'));
      push @$fields, qw(shortname secret type ports server community);
      $opt->{'labels'}{'shortname'}  = 'Short name';
      $opt->{'labels'}{'secret'}     = 'Shared secret';
      $opt->{'labels'}{'type'}       = 'Type';
      $opt->{'labels'}{'ports'}      = 'Ports';
      $opt->{'labels'}{'server'}     = 'Server';
      $opt->{'labels'}{'community'}  = 'Community';
    } #if $nas
  } #$nas_export
};


</%init>
