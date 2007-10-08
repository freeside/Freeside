%
%
%my $recnum = $cgi->param('recnum');
%
%my $old = qsearchs('agent',{'recnum'=>$recnum}) if $recnum;
%
%my $new = new FS::domain_record ( {
%  map {
%    $_, scalar($cgi->param($_));
%  } fields('domain_record')
%} );
%
%my $error;
%if ( $recnum ) {
%  $error=$new->replace($old);
%} else {
%  $error=$new->insert;
%  $recnum=$new->getfield('recnum');
%}
%
%if ( $error ) {
%#  $cgi->param('error', $error);
%#  print $cgi->redirect(popurl(2). "agent.cgi?". $cgi->query_string );
%  #no edit screen to send them back to
%

<!-- mason kludge -->
%
%  errorpage($error);
%} else { 
%  my $svcnum = $new->svcnum;
%  print $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum");
%}
%
%

