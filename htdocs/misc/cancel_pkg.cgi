#!/usr/bin/perl -Tw
#
# $Id: cancel_pkg.cgi,v 1.4 1999-01-19 05:14:04 ivan Exp $
#
# Usage: cancel_pkg.cgi pkgnum
#        http://server.name/path/cancel_pkg.cgi pkgnum
#
# Note: Should be run setuid freeside as user nobody
#
# IT DOESN'T RUN THE APPROPRIATE PROGRAMS YET!!!!
#
# probably should generalize this to do cancels, suspensions, unsuspensions, etc.
#
# ivan@voicenet.com 97-jan-2
#
# still kludgy, but now runs /dbin/cancel $pkgnum
# ivan@voicenet.com 97-feb-27
#
# doesn't run if pkgnum doesn't match regex
# ivan@voicenet.com 97-mar-6
#
# now redirects to enter comments
# ivan@voicenet.com 97-may-8
#
# rewrote for new API
# ivan@voicenet.com 97-jul-21
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cancel_pkg.cgi,v $
# Revision 1.4  1999-01-19 05:14:04  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1998/12/23 03:02:54  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:12:43  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use vars qw ( $cgi $query $pkgnum $cust_pkg $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(eidiot popurl);
use FS::Record qw(qsearchs);
use FS::cust_pkg;

$cgi = new CGI;
&cgisuidsetup($cgi);
 
#untaint pkgnum
($query) = $cgi->keywords;
$query =~ /^(\d+)$/ || die "Illegal pkgnum";
$pkgnum = $1;

$cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});

$error = $cust_pkg->cancel;
eidiot($error) if $error;

print $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

