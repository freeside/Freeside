#!/usr/bin/perl -Tw
#
# susp_pkg.cgi: Suspend a package
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

use strict;
use CGI::Base qw(:DEFAULT :CGI); # CGI module
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::cust_pkg;

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);
 
#untaint pkgnum
$QUERY_STRING =~ /^(\d+)$/ || die "Illegal pkgnum";
my($pkgnum)=$1;

my($cust_pkg) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});

bless($cust_pkg,'FS::cust_pkg');
my($error)=$cust_pkg->suspend;
&idiot($error) if $error;

$cgi->redirect("../view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

sub idiot {
  my($error)=@_;
  SendHeaders();
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error suspending package</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>Error suspending package</H1>
    </CENTER>
    <HR>
    There has been an error suspending this package:  $error
  </BODY>
  </HEAD>
</HTML>
END
  exit;
}

