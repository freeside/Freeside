<%
#<!-- $Id: cancel-unaudited.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $query $svcnum $svc_acct $cust_svc $error $dbh );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl eidiot);
use FS::Record qw(qsearchs);
use FS::cust_svc;
use FS::svc_acct;

$cgi = new CGI;
$dbh = &cgisuidsetup($cgi);
 
#untaint svcnum
($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$svcnum = $1;

$svc_acct = qsearchs('svc_acct',{'svcnum'=>$svcnum});
die "Unknown svcnum!" unless $svc_acct;

$cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
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

$error = $svc_acct->cancel;
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
