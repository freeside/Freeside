#!/usr/bin/perl -Tw
#
# View svc_domain records
#
# Usage: svc_domain svcnum
#        http://server.name/path/svc_domain.cgi?svcnum
#
# Note: Should be run setuid freeside as user nobody.
#
# ivan@voicenet.com 97-jan-6
#
# rewrite ivan@sisd.com 98-mar-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Base qw(:DEFAULT :CGI);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);

my($cgi) = new CGI::Base;
$cgi->get;
cgisuidsetup($cgi);

#untaint svcnum
$QUERY_STRING =~ /^(\d+)$/;
my($svcnum)=$1;
my($svc_domain)=qsearchs('svc_domain',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_domain;
my($domain)=$svc_domain->domain;

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
    <TITLE>Domain View</TITLE>
  </HEAD>
  <BODY>
    <CENTER><H1>Domain View</H1>
    <BASEFONT SIZE=3>
<CENTER>
<A HREF="../view/cust_pkg.cgi?$pkgnum">View this package (#$pkgnum)</A> | 
<A HREF="../view/cust_main.cgi?$custnum">View this customer (#$custnum)</A> | 
<A HREF="../">Main menu</A></CENTER><BR>
    <FONT SIZE=+1>Service #$svcnum</FONT>
    </CENTER>
END

print "<HR>";
print "Service: <B>", $part_svc->svc, "</B>";
print "<HR>";

print qq!Domain name <B>$domain</B>.!;
print qq!<P><A HREF="http://rs.internic.net/cgi-bin/whois?do+$domain">View whois information.</A>!;

print "<HR>";

	#formatting
	print <<END;

  </BODY>
</HTML>
END

