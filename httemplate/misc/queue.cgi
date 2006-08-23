%
%
%$cgi->param('action') =~ /^(new|del|(retry|remove) selected)$/
%  or die "Illegal action";
%my $action = $1;
%
%my $job;
%if ( $action eq 'new' || $action eq 'del' ) {
%  $cgi->param('jobnum') =~ /^(\d+)$/ or die "Illegal jobnum";
%  my $jobnum = $1;
%  $job = qsearchs('queue', { 'jobnum' => $1 })
%    or die "unknown jobnum $jobnum - ".
%           "it probably completed normally or was removed by another user";
%}
%
%if ( $action eq 'new' ) {
%  my %hash = $job->hash;
%  $hash{'status'} = 'new';
%  $hash{'statustext'} = '';
%  my $new = new FS::queue \%hash;
%  my $error = $new->replace($job);
%  die $error if $error;
%} elsif ( $action eq 'del' ) {
%  my $error = $job->delete;
%  die $error if $error;
%} elsif ( $action =~ /^(retry|remove) selected$/ ) {
%  foreach my $jobnum (
%    map { /^jobnum(\d+)$/; $1; } grep /^jobnum\d+$/, $cgi->param
%  ) {
%    my $job = qsearchs('queue', { 'jobnum' => $jobnum });
%    if ( $action eq 'retry selected' && $job ) { #new
%      my %hash = $job->hash;
%      $hash{'status'} = 'new';
%      $hash{'statustext'} = '';
%      my $new = new FS::queue \%hash;
%      my $error = $new->replace($job);
%      die $error if $error;
%    } elsif ( $action eq 'remove selected' && $job ) { #del
%      my $error = $job->delete;
%      die $error if $error;
%    }
%  }
%}
%
%print $cgi->redirect(popurl(2). "search/queue.html");
%
%

