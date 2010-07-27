<% $uri->query %>
<%init>

my $uri = new URI;

my($custnum, $svcnum) = $cgi->keywords;
if ( $custnum =~ /^(\d+)$/ ) {

  use FS::Maestro;
  $uri->query_form( FS::Maestro::customer_status($1) );

} else {
  $uri->query_form( { 'error' => 'No custnum' } );
}

</%init>
