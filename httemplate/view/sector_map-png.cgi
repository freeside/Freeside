<%init>
my ($sectornum) = $cgi->keywords;
my $sector = FS::tower_sector->by_key($sectornum);
if ( $sector and length($sector->image) > 0 ) {
  http_header('Content-Type', 'image/png');
  $m->print($sector->image);
}
</%init>
