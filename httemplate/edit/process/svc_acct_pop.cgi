%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "svc_acct_pop.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "browse/svc_acct_pop.cgi") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $popnum = $cgi->param('popnum');

my $old = qsearchs('svc_acct_pop',{'popnum'=>$popnum}) if $popnum;

my $new = new FS::svc_acct_pop ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('svc_acct_pop')
} );

my $error = '';
if ( $popnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $popnum=$new->getfield('popnum');
}

</%init>
