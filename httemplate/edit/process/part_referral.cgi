<%

my $refnum = $cgi->param('refnum');

my $new = new FS::part_referral ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_referral')
} );

my $error;
if ( $refnum ) {
  my $old = qsearchs( 'part_referral', { 'refnum' =>$ refnum } );
  die "(Old) Record not found!" unless $old;
  $error = $new->replace($old);
} else {
  $error = $new->insert;
}
$refnum=$new->refnum;

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "part_referral.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "browse/part_referral.cgi");
}

%>
