<%

my $dbh = dbh;
 
#untaint svcnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;

#my $svc_acct = qsearchs('svc_acct',{'svcnum'=>$svcnum});
#die "Unknown svcnum!" unless $svc_acct;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "Unknown svcnum!" unless $cust_svc;
&eidiot(qq!This account has already been audited.  Cancel the 
    <A HREF="!. popurl(2). qq!view/cust_pkg.cgi?! . $cust_svc->getfield('pkgnum') .
    qq!pkgnum"> package</A> instead.!) 
  if $cust_svc->pkgnum ne '' && $cust_svc->pkgnum ne '0';

my $error = $cust_svc->cancel;

if ( $error ) {
  %>
<!-- mason kludge -->
<%
  &eidiot($error);
} else {
  print $cgi->redirect(popurl(2));
}

%>
