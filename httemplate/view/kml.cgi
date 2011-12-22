<% $kml->archive %>\
<%init>

my $kml = Geo::GoogleEarth::Pluggable->new;
$kml->Point( map { $_=>scalar($cgi->param($_)) } qw( name lat lon ) );

#http_header('Content-Type' => 'application/vnd.google-earth.kml+xml' ); #kml
http_header('Content-Type' => 'application/vnd.google-earth.kmz' ); #kmz
( my $name = $cgi->param('name') ) =~ s/[^a-z0-9]/_/g; #perhaps too restrictive
http_header('Content-Disposition' => "filename=$name.kmz" );
</%init>
