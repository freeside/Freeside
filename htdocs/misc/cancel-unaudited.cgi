#!/usr/bin/perl -Tw
#
# $Id: cancel-unaudited.cgi,v 1.3 1998-12-23 03:02:05 ivan Exp $
#
# Usage: cancel-unaudited.cgi svcnum
#        http://server.name/path/cancel-unaudited.cgi pkgnum
#
# Note: Should be run setuid freeside as user nobody
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
# Revision 1.3  1998-12-23 03:02:05  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:12:42  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl eidiot);
use FS::Record qw(qsearchs);
use FS::cust_svc;
use FS::svc_acct;

my($cgi) = new CGI;
&cgisuidsetup($cgi);
 
#untaint svcnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my($svcnum)=$1;

my($svc_acct) = qsearchs('svc_acct',{'svcnum'=>$svcnum});
&eidiot("Unknown svcnum!") unless $svc_acct;

my($cust_svc) = qsearchs('cust_svc',{'svcnum'=>$svcnum});
&eidiot(qq!This account has already been audited.  Cancel the 
    <A HREF="!. popurl(2). qq!view/cust_pkg.cgi?! . $cust_svc->getfield('pkgnum') .
    qq!pkgnum"> package</A> instead.!) 
  if $cust_svc->getfield('pkgnum') ne '';

local $SIG{HUP} = 'IGNORE';
local $SIG{INT} = 'IGNORE';
local $SIG{QUIT} = 'IGNORE';
local $SIG{TERM} = 'IGNORE';
local $SIG{TSTP} = 'IGNORE';

my($error);

$error = $svc_acct->cancel;
&eidiot($error) if $error;
$error = $svc_acct->delete;
&eidiot($error) if $error;

$error = $cust_svc->delete;
&eidiot($error) if $error;

$cgi->redirect(popurl(2));

