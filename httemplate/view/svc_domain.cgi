<%
#
# $Id: svc_domain.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# Usage: svc_domain svcnum
#        http://server.name/path/svc_domain.cgi?svcnum
#
# ivan@voicenet.com 97-jan-6
#
# rewrite ivan@sisd.com 98-mar-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: svc_domain.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.11  2000/12/03 15:14:00  ivan
# bugfixes from Jeff Finucane <jeff@cmh.net>, thanks!
#
# Revision 1.10  1999/08/27 22:18:44  ivan
# point to patrick instead of internic!
#
# Revision 1.9  1999/04/08 12:00:19  ivan
# aesthetic update
#
# Revision 1.8  1999/02/28 00:04:04  ivan
# removed misleading comments
#
# Revision 1.7  1999/02/23 08:09:25  ivan
# beginnings of one-screen new customer entry and some other miscellania
#
# Revision 1.6  1999/01/19 05:14:23  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.5  1999/01/18 09:41:47  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.4  1998/12/23 03:10:19  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.3  1998/12/17 09:57:25  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#
# Revision 1.2  1998/11/13 09:56:50  ivan
# change configuration file layout to support multiple distinct databases (with
# own set of config files, export, etc.)
#

use strict;
use vars qw( $cgi $query $svcnum $svc_domain $domain $cust_svc $pkgnum 
             $cust_pkg $custnum $part_svc $p );
use CGI;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header menubar popurl menubar);
use FS::Record qw(qsearchs);
use FS::svc_domain;
use FS::cust_svc;
use FS::cust_pkg;
use FS::part_svc;

$cgi = new CGI;
cgisuidsetup($cgi);

($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$svcnum = $1;
$svc_domain = qsearchs('svc_domain',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_domain;

$cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
$pkgnum = $cust_svc->getfield('pkgnum');
if ($pkgnum) {
  $cust_pkg=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  $custnum=$cust_pkg->getfield('custnum');
} else {
  $cust_pkg = '';
  $custnum = '';
}

$part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unkonwn svcpart" unless $part_svc;

$domain = $svc_domain->domain;

$p = popurl(2);
print $cgi->header( '-expires' => 'now' ), header('Domain View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Cancel this (unaudited) account" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
)),
      "Service #$svcnum",
      "<BR>Service: <B>", $part_svc->svc, "</B>",
      "<BR>Domain name: <B>$domain</B>.",
      qq!<BR><BR><A HREF="http://www.geektools.com/cgi-bin/proxy.cgi?query=$domain;targetnic=auto">View whois information.</A>!,
      '</BODY></HTML>',
;
%>
