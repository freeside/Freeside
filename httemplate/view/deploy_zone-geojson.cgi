<% $content %>\
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
my $acl_edit = $curuser->access_right('Edit FCC report configuration');
my $acl_edit_global = $curuser->access_right('Edit FCC report configuration for all agents');
die "access denied"
  unless $acl_edit or $acl_edit_global;

my($name, $content);

my($query) = $cgi->keywords;
if ( $query =~ /^(\d+)$/ || $cgi->param('zonenum') =~ /^(\d+$)/ ) {
  my $zonenum = $1;
  $name = $zonenum;
  my $deploy_zone = qsearchs('deploy_zone', { 'zonenum' => $zonenum })
    or die 'unknown zonenum';

  $content = $deploy_zone->geo_json_feature->to_json;

} elsif ( $cgi->param('zonetype') =~ /^(\w)$/ ) {
  my $zonetype = $1;
  $name = $zonetype;
  my @deploy_zone = qsearch('deploy_zone', { 'zonetype' => $zonetype,
                                             'disabled' => '',        });

   my $fc = Geo::JSON::FeatureCollection->new({
     features => [ map $_->geo_json_feature, @deploy_zone ],
   });

   $content = $fc->to_json;

} else {
  die "no zonenum or zonetype\n";
}

http_header('Content-Type'        => 'application/geo+json' );
http_header('Content-Disposition' => "filename=$name.geojson" );
http_header('Content-Length'      => length($content) );
http_header('Cache-control'       => 'max-age=60' );

</%init>
