<%
# <!-- $Id: svc_forward.cgi,v 1.4 2001-10-30 14:54:07 ivan Exp $ -->

use strict;
use vars qw($conf $cgi $query $svcnum $svc_forward $cust_svc
            $pkgnum $cust_pkg $custnum $part_svc $p $srcsvc $dstsvc $dst
            $svc $svc_acct $source $destination);
use CGI;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl menubar );
use FS::Record qw(qsearchs);
use FS::Conf;
use FS::cust_svc;
use FS::cust_pkg;
use FS::part_svc;
use FS::svc_acct;
use FS::svc_forward;

$cgi = new CGI;
cgisuidsetup($cgi);

$conf = new FS::Conf;

($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$svcnum = $1;
$svc_forward = qsearchs('svc_forward',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_forward;

$cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
$pkgnum = $cust_svc->getfield('pkgnum');
if ($pkgnum) {
  $cust_pkg=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  $custnum=$cust_pkg->getfield('custnum');
} else {
  $cust_pkg = '';
  $custnum = '';
}

$part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } )
  or die "Unkonwn svcpart";

$p = popurl(2);
print header('Mail Forward View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Cancel this (unaudited) account" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
));

($srcsvc,$dstsvc,$dst) = (
  $svc_forward->srcsvc,
  $svc_forward->dstsvc,
  $svc_forward->dst,
);
$svc = $part_svc->svc;
$svc_acct = qsearchs('svc_acct',{'svcnum'=>$srcsvc})
  or die "Corrupted database: no svc_acct.svcnum matching srcsvc $srcsvc";
$source = $svc_acct->email;
if ($dstsvc) {
  $svc_acct = qsearchs('svc_acct',{'svcnum'=>$dstsvc})
    or die "Corrupted database: no svc_acct.svcnum matching dstsvc $dstsvc";
  $destination = $svc_acct->email;
}else{
  $destination = $dst;
}

print qq!<A HREF="${p}edit/svc_forward.cgi?$svcnum">Edit this information</A>!,
      "<BR>Service #$svcnum",
      "<BR>Service: <B>$svc</B>",
      qq!<BR>Mail to <B>$source</B> forwards to <B>$destination</B> mailbox.!,
      '</BODY></HTML>'
;

%>
