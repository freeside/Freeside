<%
#
# $Id: cancel-unaudited.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# Usage: cancel-unaudited.cgi svcnum
#        http://server.name/path/cancel-unaudited.cgi pkgnum
#
# ivan@voicenet.com 97-apr-23
#
# rewrote for new API
# ivan@voicenet.com 97-jul-21
#
# Search->Record, cgisuidsetup($cgi) ivan@sids.com 98-mar-19
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cancel-unaudited.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.8  2001/04/09 23:05:16  ivan
# Transactions Part I!!!
#
# Revision 1.7  2000/06/15 12:30:37  ivan
# bugfix from Jeff Finucane, thanks!
#
# Revision 1.6  1999/02/28 00:03:48  ivan
# removed misleading comments
#
# Revision 1.5  1999/02/07 09:59:34  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.4  1999/01/19 05:14:03  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1998/12/23 03:02:05  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:12:42  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

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
