<% $content %>\
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
my $acl_edit = $curuser->access_right('Edit FCC report configuration');
my $acl_edit_global = $curuser->access_right('Edit FCC report configuration for all agents');
die "access denied"
  unless $acl_edit or $acl_edit_global;

my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;

my %shapelib_opts = (
  Shapetype  => Geo::Shapelib::POLYGON,
  FieldNames => [ 'Tech', 'Down', 'Up' ],
  FieldTypes => [ 'String:32', 'Double', 'Double' ],
);

my( $name, $shapefile );

my($query) = $cgi->keywords;
if ( $query =~ /^(\d+)$/ || $cgi->param('zonenum') =~ /^(\d+$)/ ) {
  my $zonenum = $1;
  $name = $zonenum;
  my $deploy_zone = qsearchs('deploy_zone', { 'zonenum' => $zonenum })
    or die 'unknown zonenum';

  $shapefile = new Geo::Shapelib {
    Name => "$dir/$zonenum-$$",
    %shapelib_opts
  };

  $deploy_zone->shapefile_add($shapefile);

} elsif ( $cgi->param('zonetype') =~ /^(\w)$/ ) {
  my $zonetype = $1;
  $name = $zonetype;
  my @deploy_zone = qsearch('deploy_zone', { 'zonetype' => $zonetype,
                                             'disabled' => '',        });

  $shapefile = new Geo::Shapelib {
    Name => "$dir/$zonetype-$$",
    %shapelib_opts
  };

  $_->shapefile_add($shapefile) foreach @deploy_zone;

} else {
  die "no zonenum or zonetype\n";
}

$shapefile->set_bounds;

$shapefile->save;

#slurp up .shp .shx and .dbf files and put them in a zip.. return that
#and delete the files

my $content = '';
open(my $fh, '>', \$content);

my $zip = new Archive::Zip;
$zip->addFile("$dir/$name-$$.$_", "$name.$_") foreach qw( shp shx dbf );
unless ( $zip->writeToFileHandle($fh) == Archive::Zip::AZ_OK() ) {
  die "failed to create .shz file\n";
}
close $fh;

unlink("$dir/$name-$$.$_") foreach qw( shp shx dbf );

#http_header('Content-Type'        => 'x-gis/x-shapefile' );
http_header('Content-Type'        => 'archive/zip' );
http_header('Content-Disposition' => "filename=$name.shz" );
http_header('Content-Length'      => length($content) );
http_header('Cache-control'       => 'max-age=60' );

</%init>
