<%

my $eventpart = $cgi->param('eventpart');

my $old = qsearchs('part_bill_event',{'eventpart'=>$eventpart}) if $eventpart;

#s/days/seconds/
$cgi->param('seconds', $cgi->param('days') * 3600 );

my $new = new FS::part_bill_event ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_bill_event'),
} );

my $error;
if ( $eventpart ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $eventpart = $new->getfield('eventpart');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "part_bill_event.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3)."browse/part_bill_event.cgi");
}

%>

