<%

my $eventpart = $cgi->param('eventpart');

my $old = qsearchs('part_bill_event',{'eventpart'=>$eventpart}) if $eventpart;

#s/days/seconds/
$cgi->param('seconds', $cgi->param('days') * 86400 );

my $error;
if ( ! $cgi->param('plan_weight_eventcode') ) {
  $error = "Must select an action";
} else {

  $cgi->param('plan_weight_eventcode') =~ /^([\w\-]+):(\d+):(.*)$/s
    or die "illegal plan_weight_eventcode:".
           $cgi->param('plan_weight_eventcode');
  $cgi->param('plan', $1);
  $cgi->param('weight', $2);
  my $eventcode = $3;
  my $plandata = '';
  while ( $eventcode =~ /%%%(\w+)%%%/ ) {
    my $field = $1;
    my $value = $cgi->param($field);
    $eventcode =~ s/%%%$field%%%/$value/;
    $plandata .= "$field $value\n";
  }
  $cgi->param('eventcode', $eventcode);
  $cgi->param('plandata', $plandata);

  my $new = new FS::part_bill_event ( {
    map {
      $_, scalar($cgi->param($_));
    } fields('part_bill_event'),
  } );

  if ( $eventpart ) {
    $error = $new->replace($old);
  } else {
    $error = $new->insert;
    $eventpart = $new->getfield('eventpart');
  }
} 

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "part_bill_event.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3)."browse/part_bill_event.cgi");
}

%>

