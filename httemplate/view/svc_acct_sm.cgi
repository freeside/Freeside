<%
#<!-- $Id: svc_acct_sm.cgi,v 1.4 2001-10-30 14:54:07 ivan Exp $ -->

use strict;
use vars qw($conf $cgi $mydomain $query $svcnum $svc_acct_sm $cust_svc
            $pkgnum $cust_pkg $custnum $part_svc $p $domsvc $domuid $domuser
            $svc $svc_domain $domain $svc_acct $username );
use CGI;
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl menubar );
use FS::Record qw(qsearchs);
use FS::Conf;
use FS::svc_acct_sm;
use FS::cust_svc;
use FS::cust_pkg;
use FS::part_svc;
use FS::svc_domain;
use FS::svc_acct;

$cgi = new CGI;
cgisuidsetup($cgi);

$conf = new FS::Conf;
$mydomain = $conf->config('domain');

($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$svcnum = $1;
$svc_acct_sm = qsearchs('svc_acct_sm',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_acct_sm;

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
print header('Mail Alias View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Cancel this (unaudited) account" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
));

($domsvc,$domuid,$domuser) = (
  $svc_acct_sm->domsvc,
  $svc_acct_sm->domuid,
  $svc_acct_sm->domuser,
);
$svc = $part_svc->svc;
$svc_domain = qsearchs('svc_domain',{'svcnum'=>$domsvc})
  or die "Corrupted database: no svc_domain.svcnum matching domsvc $domsvc";
$domain = $svc_domain->domain;
$svc_acct = qsearchs('svc_acct',{'uid'=>$domuid})
  or die "Corrupted database: no svc_acct.uid matching domuid $domuid";
$username = $svc_acct->username;

print qq!<A HREF="${p}edit/svc_acct_sm.cgi?$svcnum">Edit this information</A>!,
      "<BR>Service #$svcnum",
      "<BR>Service: <B>$svc</B>",
      qq!<BR>Mail to <B>!, ( ($domuser eq '*') ? "<I>(anything)</I>" : $domuser ) , qq!</B>\@<B>$domain</B> forwards to <B>$username</B>\@$mydomain mailbox.!,
      '</BODY></HTML>'
;

%>
