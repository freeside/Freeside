#!/usr/bin/perl -Tw
#
# $Id: svc_domain.cgi,v 1.3 1998-12-17 09:57:25 ivan Exp $
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
#
# $Log: svc_domain.cgi,v $
# Revision 1.3  1998-12-17 09:57:25  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#
# Revision 1.2  1998/11/13 09:56:50  ivan
# change configuration file layout to support multiple distinct databases (with
# own set of config files, export, etc.)
#

use strict;
use CGI;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header menubar popurl);
use FS::Record qw(qsearchs);

my($cgi) = new CGI;
cgisuidsetup($cgi);

#untaint svcnum
$cgi->query_string =~ /^(\d+)$/;
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

my $p = popurl(2);
print $cgi->header, header('Domain View', menubar(
  "Main menu" => $p,
  "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
)), <<END;
    <BR><FONT SIZE=+1>Service #$svcnum</FONT>
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

