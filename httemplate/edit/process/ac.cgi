<%

my $acnum = $cgi->param('acnum');

my $old = qsearchs('ac',{'acnum'=>$acnum}) if $acnum;

my $new = new FS::ac ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('ac')
} );

my $error = '';
if ( $acnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $acnum=$new->getfield('acnum');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "ac.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "browse/ac.cgi");
}

%>
