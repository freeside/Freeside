%if ( $error ) {
%  $cgi->param('error',$error);
<% $cgi->redirect($p. "msgcat.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "browse/msgcat.cgi") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $error;
foreach my $param ( grep { /^\d+$/ } $cgi->param ) {
  my $old = qsearchs('msgcat', { msgnum=>$param } );
  next if $old->msg eq $cgi->param($param); #no need to update identical records
  die "editing en_US locale is currently disabled" if $old->locale eq 'en_US';
  my $new = new FS::msgcat { $old->hash };
  $new->msg($cgi->param($param));
  $error = $new->replace($old);
  last if $error;
}

</%init>
