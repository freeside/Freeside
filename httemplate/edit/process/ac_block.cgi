<%

my $new = new FS::ac_block ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('ac_block')
} );

my $error = '';
$error = $new->check;

unless ( $error ) { $error = $new->insert; }

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "ac.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(2). "ac.cgi?". $cgi->param('acnum'));
}

%>
