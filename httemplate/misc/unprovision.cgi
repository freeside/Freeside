%if ( $error ) {
%  errorpage($error);
%} elsif ( $pkgnum ) {
<% $cgi->redirect(popurl(2)."search/cust_pkg_svc.html?svcpart=$svcpart;pkgnum=$pkgnum") %>
%} else { # $custnum should always exist
<% $cgi->redirect(popurl(2)."view/cust_main.cgi?$custnum") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unprovision customer service');

#untaint svcnum
my @svcnums;
my ($pkgnum, $svcpart, $custnum);
if( $cgi->param('svcnum') ) {
  @svcnums = grep { $_ } map { /^(\d+)$/ && $1 } $cgi->param('svcnum');
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $custnum = $cgi->param('custnum');
}
else {
  @svcnums = map { /^(\d+)$/ && $1 } $cgi->keywords;
}

my $error = '';
foreach my $svcnum (@svcnums) {

  my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
  die "Unknown svcnum!" unless $cust_svc;

  $custnum ||= $cust_svc->cust_pkg->custnum;

  $error .= $cust_svc->cancel;

}

</%init>
