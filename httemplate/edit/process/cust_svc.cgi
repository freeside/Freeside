%
%
%my $svcnum = $cgi->param('svcnum');
%
%my $old = qsearchs('cust_svc',{'svcnum'=>$svcnum}) if $svcnum;
%
%my $new = new FS::cust_svc ( {
%  map {
%    $_, scalar($cgi->param($_));
%  } fields('cust_svc')
%} );
%
%my $error;
%if ( $svcnum ) {
%  $error=$new->replace($old);
%} else {
%  $error=$new->insert;
%  $svcnum=$new->getfield('svcnum');
%}
%
%if ( $error ) {
%  #$cgi->param('error', $error);
%  #print $cgi->redirect(popurl(2). "cust_svc.cgi?". $cgi->query_string );
%  errorpage($error);
%} else { 
%  my $svcdb = $new->part_svc->svcdb;
%  print $cgi->redirect(popurl(3). "view/$svcdb.cgi?$svcnum");
%}
%
%
