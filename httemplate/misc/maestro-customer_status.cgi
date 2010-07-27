<% $uri->query %>
<%init>

my $uri = new URI;

my($custnum, $svcnum) = $cgi->keywords;
if ( $custnum =~ /^(\d+)$/ ) {

  use FS::Maestro;
  $return = FS::Maestro::customer_status($1, $svcnum);

} else {
  $return = { 'error' => 'No custnum' };
}

</%init>
