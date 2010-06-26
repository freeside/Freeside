<% $uri->query %>
<%init>

my $uri = new URI;

my($query) = $cgi->keywords;
if ( $query =~ /^(\d+)$/ ) {

  use FS::Maestro;
  $uri->query_form( FS::Maestro::customer_status($1) );

} else {
  $uri->query_form( { 'error' => 'No custnum' } );
}

</%init>
