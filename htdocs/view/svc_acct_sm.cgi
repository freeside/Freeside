#!/usr/bin/perl -Tw
#
# $Id: svc_acct_sm.cgi,v 1.3 1998-12-17 09:57:24 ivan Exp $
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
# Revision 1.3  1998-12-17 09:57:24  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#
# Revision 1.2  1998/12/16 05:24:30  ivan
# use FS::Conf;
#

use strict;
use vars qw($conf);
use CGI;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearchs);
use FS::Conf;

my($cgi) = new CGI;
cgisuidsetup($cgi);

$conf = new FS::Conf;
my $mydomain = $conf->config('domain');

#untaint svcnum
$cgi->query_string =~ /^(\d+)$/;
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

print $cgi->header, header('Mail Alias View');

my $p = popurl(2);
if ($pkgnum || $custnum) {
  print <<END;
<A HREF="${p}view/cust_pkg.cgi?$pkgnum">View this package (#$pkgnum)</A> | 
<A HREF="${p}view/cust_main.cgi?$custnum">View this customer (#$custnum)</A> | 
END
} else {
  print <<END;
<A HREF="${p}misc/cancel-unaudited.cgi?$svcnum">Cancel this (unaudited)account</A> |
END
}

print <<END;
    <A HREF="${p}">Main menu</A></CENTER><BR<
    <FONT SIZE=+1>Service #$svcnum</FONT>
    <P><A HREF="${p}edit/svc_acct_sm.cgi?$svcnum">Edit this information</A>
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

