#!/usr/bin/perl -Tw
#
# cancel_pkg.cgi: Cancel a package
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

use strict;
use CGI::Base qw(:DEFAULT :CGI); # CGI module
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::cust_pkg;
use FS::CGI qw(idiot);

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);
 
#untaint pkgnum
$QUERY_STRING =~ /^(\d+)$/ || die "Illegal pkgnum";
my($pkgnum)=$1;

my($cust_pkg) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});

bless($cust_pkg,'FS::cust_pkg');
my($error)=$cust_pkg->cancel;
idiot($error) if $error;

$cgi->redirect("../view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

