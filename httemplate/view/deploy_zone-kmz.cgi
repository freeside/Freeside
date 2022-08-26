<% $content %>\
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
my $acl_edit = $curuser->access_right('Edit FCC report configuration');
my $acl_edit_global = $curuser->access_right('Edit FCC report configuration for all agents');
die "access denied"
  unless $acl_edit or $acl_edit_global;

my $kml = Geo::GoogleEarth::Pluggable->new;

my $name;

my($query) = $cgi->keywords;
if ( $query =~ /^(\d+)$/ || $cgi->param('zonenum') =~ /^(\d+$)/ ) {
  my $zonenum = $1;
  $name = $zonenum;
  my $deploy_zone = qsearchs('deploy_zone', { 'zonenum' => $zonenum })
    or die 'unknown zonenum';

  $deploy_zone->kml_polygon($kml);

} elsif ( $cgi->param('zonetype') =~ /^(\w)$/ ) {
  my $zonetype = $1;
  $name = $zonetype;
  my @deploy_zone = qsearch('deploy_zone', { 'zonetype' => $zonetype,
                                             'disabled' => '',        });

  $_->kml_polygon($kml) foreach @deploy_zone;

} else {
  die "no zonenum or zonetype\n";
}

my $content = $kml->archive;

http_header('Content-Type' => 'application/vnd.google-earth.kmz' ); #kmz
http_header('Content-Disposition' => "filename=$name.kmz" );
http_header('Content-Length'      => length($content) );
http_header('Cache-control'       => 'max-age=60' );

</%init>
