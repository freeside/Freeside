<!-- $Id: cancel-unaudited.cgi,v 1.3 2002-01-30 14:18:09 ivan Exp $ -->

my $dbh = dbh;
 
#untaint svcnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;

my $svc_acct = qsearchs('svc_acct',{'svcnum'=>$svcnum});
die "Unknown svcnum!" unless $svc_acct;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
&eidiot(qq!This account has already been audited.  Cancel the 
    <A HREF="!. popurl(2). qq!view/cust_pkg.cgi?! . $cust_svc->getfield('pkgnum') .
    qq!pkgnum"> package</A> instead.!) 
  if $cust_svc->pkgnum ne '' && $cust_svc->pkgnum ne '0';

local $SIG{HUP} = 'IGNORE';
local $SIG{INT} = 'IGNORE';
local $SIG{QUIT} = 'IGNORE';
local $SIG{TERM} = 'IGNORE';
local $SIG{TSTP} = 'IGNORE';

local $FS::UID::AutoCommit = 0;

my $error = $svc_acct->cancel;
&myeidiot($error) if $error;
$error = $svc_acct->delete;
&myeidiot($error) if $error;

$error = $cust_svc->delete;
&myeidiot($error) if $error;

$dbh->commit or die $dbh->errstr;

print $cgi->redirect(popurl(2));

sub myeidiot {
  $dbh->rollback;
  &eidiot(@_);
}

%>
