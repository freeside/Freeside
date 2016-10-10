<% encode_json({
  type => 'FeatureCollection',
  features => \@features
}) %>
<%init>

die "access denied" unless
  $FS::CurrentUser::CurrentUser->access_right('List services');

my $conf = new FS::Conf;

my @features; # geoJSON structure

# accept all the search logic from svc_broadband.cgi...
my %search_hash;
if ( $cgi->param('magic') eq 'unlinked' ) {
  %search_hash = ( 'unlinked' => 1 );
} else {
  foreach (qw( custnum agentnum svcpart cust_fields )) {
    $search_hash{$_} = $cgi->param($_) if $cgi->param($_);
  }
  foreach (qw(pkgpart routernum towernum sectornum)) {
    $search_hash{$_} = [ $cgi->param($_) ] if $cgi->param($_);
  }
}

if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
  $search_hash{'order_by'} = "ORDER BY $1";
}

my $sql_query = FS::svc_broadband->search(\%search_hash);

my %routerbyblock = ();

my @rows = qsearch($sql_query);
my %sectors;
my %towers;
my %tower_coord;

foreach my $svc_broadband (@rows) {
  # don't try to show it if coords aren't set
  next if !$svc_broadband->latitude || !$svc_broadband->longitude;
  # coerce coordinates to numbers
  my @coord = (
    $svc_broadband->longitude + 0,
    $svc_broadband->latitude + 0,
  );
  push @coord, $svc_broadband->altitude + 0
    if length($svc_broadband->altitude); # it's optional

  my $svcnum = $svc_broadband->svcnum;
  my $color = $svc_broadband->addr_status_color;

  push @features,
  {
    type      => 'Feature',
    id        => 'svc_broadband/'.$svcnum,
    geometry  => {
      type        => 'Point',
      coordinates => \@coord,
    },
    properties => {
      #content => include('.svc_broadband', $svc_broadband),
      url   => $fsurl . 'view/svc_broadband-popup.html?' . $svcnum,
      style => {
        icon => {
          fillColor => $color,
        },
      },
    },
  };
  # look up tower location and draw connecting line
  next if !$svc_broadband->sectornum;
  my $sector = $sectors{$svc_broadband->sectornum} ||= $svc_broadband->tower_sector;
  my $towernum = $sector->towernum;
  my $tower = $towers{$towernum};

  if (!$tower) {
    $tower = $towers{$towernum} = $sector->tower;
    $tower_coord{$towernum} =
      [ $tower->longitude + 0,
        $tower->latitude + 0,
        ($tower->altitude || 0) + 0,
      ];

  }

  if ( $tower->latitude and $tower->longitude ) {
    push @features,
    {
      type => 'Feature',
      id   => 'svc_broadband/'.$svcnum.'/line',
      geometry => {
        type        => 'LineString',
        coordinates => [ \@coord, $tower_coord{$towernum} ],
      },
      properties  => {
        style       => {
          visible      => 0,
          strokeColor  => $color,
          strokeWeight => 2,
        },
      },
    };

  } # if tower has coords
} # foreach $svc_broadband
</%init>
