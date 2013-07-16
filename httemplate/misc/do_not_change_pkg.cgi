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

my $error = $cust_pkg->abort_change;

</%init>
