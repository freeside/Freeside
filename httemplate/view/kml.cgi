<% $kml->archive %>\
<%init>

my ($latitude, $longitude, $name) = @_;
#would be nice to pass in customer or prospect name too...

my $kml = Geo::GoogleEarth::Pluggable->new;
$kml->Point( map { $_=>scalar($cgi->param($_)) } qw( name lat lon ) );

#http_header('Content-Type' => 'application/vnd.google-earth.kml+xml' ); #kml
http_header('Content-Type' => 'application/vnd.google-earth.kmz' ); #kmz

</%init>
