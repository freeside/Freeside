<%

$cgi->param('jobnum') =~ /^(\d+)$/ or die "Illegal jobnum";
my $jobnum = $1;
my $job = qsearchs('queue', { 'jobnum' => $1 })
  or die "unknown jobnum $jobnum";

$cgi->param('action') =~ /^(new|del)$/ or die "Illegal action";
my $action = $1;

if ( $action eq 'new' ) {
  my %hash = $job->hash;
  $hash{'status'} = 'new';
  $hash{'statustext'} = '';
  my $new = new FS::queue \%hash;
  my $error = $new->replace($job);
  die $error if $error;
} elsif ( $action eq 'del' ) {
  my $error = $job->delete;
  die $error if $error;
}

print $cgi->redirect(popurl(2). "browse/queue.cgi");

%>
