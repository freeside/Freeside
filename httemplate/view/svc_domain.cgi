<%
# <!-- $Id: svc_domain.cgi,v 1.5 2001-10-30 14:54:07 ivan Exp $ -->

use strict;
use vars qw( $cgi $query $svcnum $svc_domain $domain $cust_svc $pkgnum 
             $cust_pkg $custnum $part_svc $p $svc_acct $email);
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
die "Unknown svcpart" unless $part_svc;

if ($svc_domain->catchall) {
  $svc_acct = qsearchs('svc_acct',{'svcnum'=> $svc_domain->catchall } );
  die "Unknown svcpart" unless $svc_acct;
  $email = $svc_acct->email;
}

$domain = $svc_domain->domain;

$p = popurl(2);
print header('Domain View', menubar(
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
      qq!<BR>Catch all email <A HREF="${p}misc/catchall.cgi?$svcnum">(change)</A>:!,
      $email ? "<B>$email</B>." : "<I>(none)<I>",
      qq!<BR><BR><A HREF="http://www.geektools.com/cgi-bin/proxy.cgi?query=$domain;targetnic=auto">View whois information.</A>!,
      '</BODY></HTML>',
;
%>
