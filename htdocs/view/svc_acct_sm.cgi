#!/usr/bin/perl -Tw
#
# $Id: svc_acct_sm.cgi,v 1.2 1998-12-16 05:24:30 ivan Exp $
#
# Usage: svc_acct_sm.cgi svcnum
#        http://server.name/path/svc_acct_sm.cgi?svcnum
#
# Note: Should be run setuid freeside as user nobody.
#
# based on view/svc_acct.cgi
# 
# ivan@voicenet.com 97-jan-5
#
# added navigation bar
# ivan@voicenet.com 97-jan-30
# 
# rewrite ivan@sisd.com 98-mar-15
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# /var/spool/freeside/conf/domain ivan@sisd.com 98-jul-17
#
# $Log: svc_acct_sm.cgi,v $
# Revision 1.2  1998-12-16 05:24:30  ivan
# use FS::Conf;
#

use strict;
use vars qw($conf);
use CGI::Base qw(:DEFAULT :CGI);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::Conf;

$conf = new FS::Conf;
my $mydomain = $conf->config('domain');

my($cgi) = new CGI::Base;
$cgi->get;
cgisuidsetup($cgi);

#untaint svcnum
$QUERY_STRING =~ /^(\d+)$/;
my($svcnum)=$1;
my($svc_acct_sm)=qsearchs('svc_acct_sm',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_acct_sm;

my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum});
my($pkgnum)=$cust_svc->getfield('pkgnum');
my($cust_pkg,$custnum);
if ($pkgnum) {
  $cust_pkg=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  $custnum=$cust_pkg->getfield('custnum');
}

my($part_svc)=qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unkonwn svcpart" unless $part_svc;

SendHeaders(); # one guess.
print <<END;
<HTML>
  <HEAD>
    <TITLE>Mail Alias View</TITLE>
  </HEAD>
  <BODY>
    <CENTER><H1>Mail Alias View</H1>
END
if ($pkgnum || $custnum) {
  print <<END;
<A HREF="../view/cust_pkg.cgi?$pkgnum">View this package (#$pkgnum)</A> | 
<A HREF="../view/cust_main.cgi?$custnum">View this customer (#$custnum)</A> | 
END
} else {
  print <<END;
<A HREF="../misc/cancel-unaudited.cgi?$svcnum">Cancel this (unaudited)account</A> |
END
}

print <<END;
    <A HREF="../">Main menu</A></CENTER><BR<
    <FONT SIZE=+1>Service #$svcnum</FONT>
    <P><A HREF="../edit/svc_acct_sm.cgi?$svcnum">Edit this information</A>
    <BASEFONT SIZE=3>
END

my($domsvc,$domuid,$domuser)=(
  $svc_acct_sm->domsvc,
  $svc_acct_sm->domuid,
  $svc_acct_sm->domuser,
);
my($svc) = $part_svc->svc;
my($svc_domain)=qsearchs('svc_domain',{'svcnum'=>$domsvc});
my($domain)=$svc_domain->domain;
my($svc_acct)=qsearchs('svc_acct',{'uid'=>$domuid});
my($username)=$svc_acct->username;

#formatting
print qq!<HR>!;

#svc
print "Service: <B>$svc</B>";

print "<HR>";

print qq!Mail to <B>!, ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser ) , qq!</B>\@<B>$domain</B> forwards to <B>$username</B>\@$mydomain mailbox.!;

print "<HR>";

	#formatting
	print <<END;

  </BODY>
</HTML>
END

