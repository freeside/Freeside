%if ( $error ) {
%  errorpage($error);
%} else { 
%  my $svcnum = $new->svcnum;
<% $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit domain nameservice');

my $recnum = $cgi->param('recnum');

my $old = qsearchs('domain_record',{'recnum'=>$recnum}) if $recnum;

my $new = new FS::domain_record ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('domain_record')
} );

my $error;
if ( $recnum ) {
  $error=$new->replace($old);
} else {
  $error=$new->insert;
  $recnum=$new->getfield('recnum');
}

</%init>
