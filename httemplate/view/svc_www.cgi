<%
# <!-- $Id: svc_www.cgi,v 1.1 2001-12-15 22:56:07 ivan Exp $ -->

use strict;
use vars qw( $cgi $query $svcnum $svc_www $cust_svc $pkgnum
             $cust_pkg $custnum $p $domain_record );
             #$part_svc $p $svc_acct $email
use CGI;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header menubar popurl menubar);
use FS::Record qw(qsearchs);
use FS::svc_www;
use FS::domain_record;
use FS::cust_svc;
#use FS::cust_pkg;
#use FS::part_svc;

$cgi = new CGI;
cgisuidsetup($cgi);

($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$svcnum = $1;
$svc_www = qsearchs( 'svc_www', { 'svcnum' => $svcnum } )
  or die "svc_www: Unknown svcnum $svcnum";

#false laziness w/all svc_*.cgi
$cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $svcnum } );
$pkgnum = $cust_svc->getfield('pkgnum');
if ($pkgnum) {
  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
  $custnum = $cust_pkg->custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}
#eofalse

$domain_record = qsearchs( 'domain_record', { 'recnum' => $svc_www->recnum } )
  or die "svc_www: Unknown recnum". $svc_www->recnum;

my $www = $domain_record->reczone;

$p = popurl(2);
print header('Website View', menubar(
  ( ( $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )                                                                       
    : ( "Cancel this (unaudited) website" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
)),
      "Service #$svcnum",
      "<BR>Website name: <B>$www</B>.",
      '</BODY></HTML>',                
;
%>
