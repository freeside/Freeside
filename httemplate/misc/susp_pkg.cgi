<%
#
# $Id: susp_pkg.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# Usage: susp_pkg.cgi pkgnum
#        http://server.name/path/susp_pkg.cgi pkgnum
#
# probably should generalize this to do cancels, suspensions, unsuspensions, etc.
#
# ivan@voicenet.com 97-feb-27
#
# now redirects to enter comments
# ivan@voicenet.com 97-may-8
#
# rewrote for new API
# ivan@voicenet.com 97-jul-21
#
# FS::Search -> FS::Record ivan@sisd.com 98-mar-17
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: susp_pkg.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.6  1999/04/08 10:35:02  ivan
# import necessary subroutines from FS::CGI
#
# Revision 1.5  1999/02/28 00:03:52  ivan
# removed misleading comments
#
# Revision 1.4  1999/01/19 05:14:08  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1998/12/23 03:04:56  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:12:48  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

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
