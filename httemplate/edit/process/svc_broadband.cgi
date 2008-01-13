%if ( $error ) {
%  $cgi->param('error', $error);
%  $cgi->param('ip_addr', $new->ip_addr);
<% $cgi->redirect(popurl(2). "svc_broadband.cgi?". $cgi->query_string ) %>
%} else {
<% $cgi->redirect(popurl(3). "view/svc_broadband.cgi?" . $svcnum ) %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;

my $old;
if ( $svcnum ) {
  $old = qsearchs('svc_broadband', { 'svcnum' => $svcnum } )
    or die "fatal: can't find broadband service (svcnum $svcnum)!";
} else {
  $old = '';
}

my $new = new FS::svc_broadband ( {
  map {
    ($_, scalar($cgi->param($_)));
  } ( fields('svc_broadband'), qw( pkgnum svcpart ) )
} );

my $error;
if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->svcnum;
}

</%init>
