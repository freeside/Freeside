%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect(popurl(2)) %>
%}

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unprovision customer service')
      && $FS::CurrentUser::CurrentUser->access_right('View/link unlinked services');

#untaint svcnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;

#my $svc_acct = qsearchs('svc_acct',{'svcnum'=>$svcnum});
#die "Unknown svcnum!" unless $svc_acct;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "Unknown svcnum!" unless $cust_svc;
my $cust_pkg = $cust_svc->cust_pkg;
if ( $cust_pkg ) {
  errorpage( 'This account has already been audited.  Cancel the '.
           qq!<A HREF="${p}view/cust_main.cgi?!. $cust_pkg->custnum.
           '#cust_pkg'. $cust_pkg->pkgnum. '">'.
           'package</A> instead.');
}

my $error = $cust_svc->cancel;

</%init>
