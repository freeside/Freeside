%if ( $error ) {
%  errorpage($error);
%} else {
<% $cgi->redirect(popurl(2)."view/cust_main.cgi?$custnum") %>
%}
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Unprovision customer service');

#untaint svcnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;

#my $svc_acct = qsearchs('svc_acct',{'svcnum'=>$svcnum});
#die "Unknown svcnum!" unless $svc_acct;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "Unknown svcnum!" unless $cust_svc;

my $custnum = $cust_svc->cust_pkg->custnum;

my $error = $cust_svc->cancel;

</%init>
