<% encode_json($collection) %>
<%init>
my @sectors;
if ( my $towernum = $cgi->param('towernum') ) {
  @sectors = qsearch('tower_sector', { towernum => $towernum });
} elsif ( my $sectornum = $cgi->param('sectornum') ) {
  @sectors = FS::tower_sector->by_key($sectornum);
} else {
  die "towernum or sectornum required";
}
my @features;
my $collection = {
  type => 'FeatureCollection',
  features => \@features,
};
foreach my $sector (@sectors) {
  my $sectornum = $sector->sectornum;
  my $low = $sector->db_low;
  my $high = $sector->db_high;
  my $color = '#' . ($sector->tower->color || 'ffffff');
  foreach my $coverage ( $sector->sector_coverage ) {
    #note $coverage->geometry is already JSON
    my $level = $coverage->db_loss;
    push @features, {
      type => 'Feature',
      id => "sector/$sectornum/$level",
      properties => {
        level => $level,
        low   => ($level == $low ? 1 : 0),
        high  => ($level == $high ? 1 : 0),
        style => {
          strokeColor => $color,
          fillColor => $color,
        },
      },
      geometry => decode_json($coverage->geometry),
    };
  }
}
</%init>
