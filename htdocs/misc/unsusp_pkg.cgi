#!/usr/bin/perl -Tw
#
# $Id: unsusp_pkg.cgi,v 1.2 1998-12-17 09:12:49 ivan Exp $
#
# Usage: susp_pkg.cgi pkgnum
#        http://server.name/path/susp_pkg.cgi pkgnum
#
# Note: Should be run setuid freeside as user nobody
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
# $Log: unsusp_pkg.cgi,v $
# Revision 1.2  1998-12-17 09:12:49  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl eidiot);
use FS::Record qw(qsearchs);
use FS::cust_pkg;

my($cgi) = new CGI;
&cgisuidsetup($cgi);
 
#untaint pkgnum
$cgi->query_string =~ /^(\d+)$/ || die "Illegal pkgnum";
my($pkgnum)=$1;

my($cust_pkg) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});

my($error)=$cust_pkg->unsuspend;
&eidiot($error) if $error;

print $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

