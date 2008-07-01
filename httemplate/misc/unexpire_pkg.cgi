%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum')) %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Cancel customer package later');

my ($pkgnum) = $cgi->keywords;
my $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
my $error = "No package $pkgnum" unless $cust_pkg;

$error ||= $cust_pkg->unexpire;

</%init>
