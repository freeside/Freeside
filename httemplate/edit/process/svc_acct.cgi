%
%
%$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
%my $svcnum = $1;
%
%my $old;
%if ( $svcnum ) {
%  $old = qsearchs('svc_acct', { 'svcnum' => $svcnum } )
%    or die "fatal: can't find account (svcnum $svcnum)!";
%} else {
%  $old = '';
%}
%
%#unmunge popnum
%$cgi->param('popnum', (split(/:/, $cgi->param('popnum') ))[0] );
%
%#unmunge passwd
%if ( $cgi->param('_password') eq '*HIDDEN*' ) {
%  die "fatal: no previous account to recall hidden password from!" unless $old;
%  $cgi->param('_password',$old->getfield('_password'));
%}
%
%#unmunge usergroup
%$cgi->param('usergroup', [ $cgi->param('radius_usergroup') ] );
%
%my %hash = $svcnum ? $old->hash : ();
%map {
%    $hash{$_} = scalar($cgi->param($_));
%  #} qw(svcnum pkgnum svcpart username _password popnum uid gid finger dir
%  #  shell quota slipip)
%  } (fields('svc_acct'), qw ( pkgnum svcpart usergroup ));
%my $new = new FS::svc_acct ( \%hash );
%
%my $error;
%if ( $svcnum ) {
%  $error = $new->replace($old);
%} else {
%  $error = $new->insert;
%  $svcnum = $new->svcnum;
%}
%
%if ( $error ) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(2). "svc_acct.cgi?". $cgi->query_string );
%} else {
%  print $cgi->redirect(popurl(3). "view/svc_acct.cgi?" . $svcnum );
%}
%
%

