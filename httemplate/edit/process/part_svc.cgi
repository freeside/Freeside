<%

my $svcpart = $cgi->param('svcpart');

my $old = qsearchs('part_svc',{'svcpart'=>$svcpart}) if $svcpart;

my $new = new FS::part_svc ( {
  map {
    $_, scalar($cgi->param($_));
#  } qw(svcpart svc svcdb)
  } fields('part_svc')
} );

my $error;
if ( $svcpart ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcpart=$new->getfield('svcpart');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2), "part_svc.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3)."browse/part_svc.cgi");
}

%>
