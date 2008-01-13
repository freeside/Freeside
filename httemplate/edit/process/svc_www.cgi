%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "svc_www.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "view/svc_www.cgi?" . $svcnum ) %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;

my $old;
if ( $svcnum ) {
  $old = qsearchs('svc_www', { 'svcnum' => $svcnum } )
    or die "fatal: can't find website (svcnum $svcnum)!";
} else {
  $old = '';
}

my $new = new FS::svc_www ( {
  map {
    ($_, scalar($cgi->param($_)));
  #} qw(svcnum pkgnum svcpart recnum usersvc)
  } ( fields('svc_www'), qw( pkgnum svcpart ) )
} );

my $error;
if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->svcnum;
}

</%init>
