%
%
%#remove this to actually test the domains!
%$FS::svc_domain::whois_hack = 1;
%
%$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
%my $svcnum = $1;
%
%my $new = new FS::svc_domain ( {
%  map {
%    $_, scalar($cgi->param($_));
%  #} qw(svcnum pkgnum svcpart domain action purpose)
%  } ( fields('svc_domain'), qw( pkgnum svcpart action purpose ) )
%} );
%
%my $error = '';
%if ($cgi->param('svcnum')) {
%  $error="Can't modify a domain!";
%} else {
%  $error=$new->insert;
%  $svcnum=$new->svcnum;
%}
%
%if ($error) {
%  $cgi->param('error', $error);
%  print $cgi->redirect(popurl(2). "svc_domain.cgi?". $cgi->query_string );
%} else {
%  print $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum");
%}
%
%

