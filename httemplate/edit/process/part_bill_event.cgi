%
%my $eventpart = $cgi->param('eventpart');
%
%my $old = qsearchs('part_bill_event',{'eventpart'=>$eventpart}) if $eventpart;
%
%#s/days/seconds/
%$cgi->param('seconds', int( $cgi->param('days') * 86400 ) );
%
%my $error;
%if ( ! $cgi->param('plan_weight_eventcode') ) {
%  $error = "Must select an action";
%} else {
%
%  $cgi->param('plan_weight_eventcode') =~ /^([\w\-]+):(\d+):(.*)$/s
%    or die "illegal plan_weight_eventcode:".
%           $cgi->param('plan_weight_eventcode');
%  $cgi->param('plan', $1);
%  $cgi->param('weight', $2);
%  my $eventcode = $3;
%  my $plandata = '';
%
%  my $rnum;
%  my $rtype;
%  my $reasonm;
%  my $class  = '';
%  $class='c' if ($eventcode =~ /cancel/);
%  $class='s' if ($eventcode =~ /suspend/);
%  if ($class) {
%    $cgi->param("${class}reason") =~ /^(-?\d+)$/
%      or $error =  "Invalid ${class}reason";
%    $rnum = $1;
%    if ($rnum == -1) {
%      $cgi->param("new${class}reasonT") =~ /^(\d+)$/
%        or $error =  "Invalid new${class}reasonT";
%      $rtype = $1;
%      $cgi->param("new${class}reason") =~ /^([\s\w]+)$/
%        or $error = "Invalid new${class}reason";
%      $reasonm = $1;
%    }
%  }
% 
%  if ($rnum == -1 && !$error) {
%    my $reason = new FS::reason ({ 'reason'      => $reasonm,
%                                   'reason_type' => $rtype,
%                                 });
%    $error = $reason->insert;
%    unless ($error) {
%      $rnum = $reason->reasonnum;
%      $cgi->param("${class}reason", $rnum);
%      $cgi->param("new${class}reason", '');
%      $cgi->param("new${class}reasonT", '');
%    }
%  }
%
%  while ( $eventcode =~ /%%%(\w+)%%%/ ) {
%    my $field = $1;
%    my $value = join(', ', $cgi->param($field) );
%    $cgi->param($field, $value); #in case it errors out
%    $eventcode =~ s/%%%$field%%%/$value/;
%    $plandata .= "$field $value\n";
%  }
%  $cgi->param('eventcode', $eventcode);
%  $cgi->param('plandata', $plandata);
%
%  unless($error){
%    my $new = new FS::part_bill_event ( {
%      map {
%        $_, scalar($cgi->param($_));
%      } fields('part_bill_event'),
%    } );
%    $new->setfield('reason', $rnum);
%
%    if ( $eventpart ) {
%      $error = $new->replace($old);
%    } else {
%      $error = $new->insert;
%      $eventpart = $new->getfield('eventpart');
%    }
%  }
%} 
%
%if ( $error ) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(2). "part_bill_event.cgi?". $cgi->query_string );
%} else {
%  print $cgi->redirect(popurl(3)."browse/part_bill_event.cgi");
%}
%
%
