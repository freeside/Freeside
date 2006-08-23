%
%
%my $error;
%foreach my $param ( grep { /^\d+$/ } $cgi->param ) {
%  my $old = qsearchs('msgcat', { msgnum=>$param } );
%  next if $old->msg eq $cgi->param($param); #no need to update identical records
%  my $new = new FS::msgcat { $old->hash };
%  $new->msg($cgi->param($param));
%  $error = $new->replace($old);
%  last if $error;
%}
%
%if ( $error ) {
%  $cgi->param('error',$error);
%  print $cgi->redirect($p. "msgcat.cgi?". $cgi->query_string );
%} else {
%  print $cgi->redirect(popurl(3). "browse/msgcat.cgi");
%}
%
%

