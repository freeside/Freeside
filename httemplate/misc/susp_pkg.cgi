<%
#<!-- $Id: susp_pkg.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $query $pkgnum $cust_pkg $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::CGI qw(popurl eidiot);
use FS::cust_pkg;

$cgi = new CGI;
&cgisuidsetup($cgi);
 
#untaint pkgnum
($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal pkgnum";
$pkgnum = $1;

$cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});

$error = $cust_pkg->suspend;
&eidiot($error) if $error;

print $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

%>
