#!/usr/bin/perl -Tw
#
# cancel-unaudited.cgi: Cancel an unaudited account
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

use strict;
use CGI::Base qw(:DEFAULT :CGI); # CGI module
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::cust_svc;
use FS::svc_acct;

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);
 
#untaint svcnum
$QUERY_STRING =~ /^(\d+)$/;
my($svcnum)=$1;

my($svc_acct) = qsearchs('svc_acct',{'svcnum'=>$svcnum});
&idiot("Unknown svcnum!") unless $svc_acct;

my($cust_svc) = qsearchs('cust_svc',{'svcnum'=>$svcnum});
&idiot(qq!This account has already been audited.  Cancel the 
    <A HREF="../view/cust_pkg.cgi?! . $cust_svc->getfield('pkgnum') .
    qq!pkgnum"> package</A> instead.!) 
  if $cust_svc->getfield('pkgnum') ne '';

local $SIG{HUP} = 'IGNORE';
local $SIG{INT} = 'IGNORE';
local $SIG{QUIT} = 'IGNORE';
local $SIG{TERM} = 'IGNORE';
local $SIG{TSTP} = 'IGNORE';

my($error);

bless($svc_acct,"FS::svc_acct");
$error = $svc_acct->cancel;
&idiot($error) if $error;
$error = $svc_acct->delete;
&idiot($error) if $error;

bless($cust_svc,"FS::cust_svc");
$error = $cust_svc->delete;
&idiot($error) if $error;

$cgi->redirect("../");

sub idiot {
  my($error)=@_;
  SendHeaders();
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error cancelling account</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>Error cancelling account</H1>
    </CENTER>
    <HR>
    There has been an error cancelling this acocunt:  $error
  </BODY>
  </HEAD>
</HTML>
END
  exit;
}

