<!-- mason kludge -->
%
%
%print header('NAS ports', menubar(
%  'Main Menu' => $p,
%));
%
%my $now = time;
%
%foreach my $nas ( sort { $a->nasnum <=> $b->nasnum } qsearch( 'nas', {} ) ) {
%  print $nas->nasnum. ": ". $nas->nas. " ".
%        $nas->nasfqdn. " (". $nas->nasip. ") ".
%        "as of ". time2str("%c",$nas->last).
%        " (". &pretty_interval($now - $nas->last). " ago)<br>".
%        &table(). "<TR><TH>Nas<BR>Port #</TH><TH>Global<BR>Port #</BR></TH>".
%        "<TH>IP address</TH><TH>User</TH><TH>Since</TH><TH>Duration</TH><TR>",
%  ;
%  foreach my $port ( sort {
%    $a->nasport <=> $b->nasport || $a->portnum <=> $b->portnum
%  } qsearch( 'port', { 'nasnum' => $nas->nasnum } ) ) {
%    my $session = $port->session;
%    my($user, $since, $pretty_since, $duration);
%    if ( ! $session ) {
%      $user = "(empty)";
%      $since = 0;
%      $pretty_since = "(never)";
%      $duration = '';
%    } elsif ( $session->logout ) {
%      $user = "(empty)";
%      $since = $session->logout;
%    } else {
%      my $svc_acct = $session->svc_acct;
%      $user = "<A HREF=\"$p/view/svc_acct.cgi?". $svc_acct->svcnum. "\">".
%              $svc_acct->username. "</A>";
%      $since = $session->login;
%    }
%    $pretty_since = time2str("%c", $since) if $since;
%    $duration = pretty_interval( $now - $since ). " ago"
%      unless defined($duration);
%    print "<TR><TD>". $port->nasport. "</TD><TD>". $port->portnum. "</TD><TD>".
%          $port->ip. "</TD><TD>$user</TD><TD>$pretty_since".
%          "</TD><TD>$duration</TD></TR>"
%    ;
%  }
%  print "</TABLE><BR>";
%}
%
%#Time::Duration??
%sub pretty_interval {
%  my $interval = shift;
%  my %howlong = (
%    '604800' => 'week',
%    '86400'  => 'day',
%    '3600'   => 'hour',
%    '60'     => 'minute',
%    '1'      => 'second',
%  );
%
%  my $pretty = "";
%  foreach my $key ( sort { $b <=> $a } keys %howlong ) {
%    my $value = int( $interval / $key );
%    if ( $value  ) {
%      if ( $value == 1 ) {
%        $pretty .=
%          ( $howlong{$key} eq 'hour' ? 'an ' : 'a ' ). $howlong{$key}. " "
%      } else {
%        $pretty .= $value. ' '. $howlong{$key}. 's ';
%      }
%    }
%    $interval -= $value * $key;
%  }
%  $pretty =~ /^\s*(\S.*\S)\s*$/;
%  $1;
%} 
%
%#print &table(), <<END;
%#<TR>
%#  <TH>#</TH>
%#  <TH>NAS</
%

