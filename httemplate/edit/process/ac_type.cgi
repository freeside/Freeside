<%

my $actypenum = $cgi->param('actypenum');

my $old = qsearchs('ac_type',{'actypenum'=>$actypenum}) if $actypenum;

my $new = new FS::ac_type ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('ac_type')
} );

my $error = '';
if ( $actypenum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $actypenum=$new->getfield('actypenum');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "ac_type.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "browse/ac_type.cgi");
}

%>
