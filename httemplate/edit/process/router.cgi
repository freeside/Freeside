%
%
%local $FS::UID::AutoCommit=0;
%
%sub check {
%  my $error = shift;
%  if($error) {
%    $cgi->param('error', $error);
%    print $cgi->redirect(popurl(3) . "edit/router.cgi?". $cgi->query_string);
%    dbh->rollback;
%    exit;
%  }
%}
%
%my $error = '';
%my $routernum  = $cgi->param('routernum');
%my $routername = $cgi->param('routername');
%my $old = qsearchs('router', { routernum => $routernum });
%my @old_psr;
%
%my $new = new FS::router {
%  map {
%    ($_, scalar($cgi->param($_)));
%  } fields('router')
%};
%
%if($old) {
%  $error = $new->replace($old);
%} else {
%  $error = $new->insert;
%  $routernum = $new->routernum;
%}
%
%check($error);
%
%if ($old) {
%  @old_psr = $old->part_svc_router;
%  foreach my $psr (@old_psr) {
%    if($cgi->param('svcpart_'.$psr->svcpart) eq 'ON') {
%      # do nothing
%    } else {
%      $error = $psr->delete;
%    }
%  }
%  check($error);
%}
%
%foreach($cgi->param) {
%  if($cgi->param($_) eq 'ON' and /^svcpart_(\d+)$/) {
%    my $svcpart = $1;
%    if(grep {$_->svcpart == $svcpart} @old_psr) {
%      # do nothing
%    } else {
%      my $new_psr = new FS::part_svc_router { svcpart   => $svcpart,
%                                              routernum => $routernum };
%      $error = $new_psr->insert;
%    }
%    check($error);
%  }
%}
%
%
%# Yay, everything worked!
%dbh->commit or die dbh->errstr;
%print $cgi->redirect(popurl(3). "browse/router.cgi");
%
%

