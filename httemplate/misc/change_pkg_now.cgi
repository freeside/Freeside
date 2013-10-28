%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum')) %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Change customer package');

#untaint pkgnum
my ($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal pkgnum";
my $pkgnum = $1;

my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
my $change_to = FS::cust_pkg->by_key($cust_pkg->change_to_pkgnum);

my $err_or_pkg = $cust_pkg->change({ 'cust_pkg' => $change_to });
my $error = $err_or_pkg unless ref($err_or_pkg);

</%init>
