<%
# <!-- $Id: svc_acct.cgi,v 1.4 2001-09-11 23:44:01 ivan Exp $ -->

use strict;
use vars qw( $conf $cgi $svc_domain $query $svcnum $svc_acct $cust_svc $pkgnum
             $cust_pkg $custnum $part_svc $p $svc_acct_pop $password );
use CGI;
use CGI::Carp qw( fatalsToBrowser );
use FS::UID qw( cgisuidsetup );
use FS::CGI qw( header popurl menubar);
use FS::Record qw( qsearchs fields );
use FS::Conf;
use FS::svc_acct;
use FS::cust_svc;
use FS::cust_pkg;
use FS::part_svc;
use FS::svc_acct_pop;
use FS::raddb;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;

($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$svcnum = $1;
$svc_acct = qsearchs('svc_acct',{'svcnum'=>$svcnum});
die "Unknown svcnum" unless $svc_acct;

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

$svc_domain = qsearchs('svc_domain', { 'svcnum' => $svc_acct->domsvc } );
die "Unknown domain" unless $svc_domain;

$p = popurl(2);
print $cgi->header( '-expires' => 'now' ), header('Account View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this package (#$pkgnum)" => "${p}view/cust_pkg.cgi?$pkgnum",
        "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Cancel this (unaudited) account" =>
          "${p}misc/cancel-unaudited.cgi?$svcnum" )
  ),
  "Main menu" => $p,
));

#print qq!<BR><A HREF="../misc/sendconfig.cgi?$svcnum">Send account information</A>!;

print qq!<A HREF="${p}edit/svc_acct.cgi?$svcnum">Edit this information</A>!,
      "<BR>Service #$svcnum",
      "<BR>Service: <B>", $part_svc->svc, "</B>",
      "<BR><BR>Username: <B>", $svc_acct->username, "</B>"
;

print "<BR>Domain: <B>", $svc_domain->domain, "</B>";

print "<BR>Password: ";
$password = $svc_acct->_password;
if ( $password =~ /^\*\w+\* (.*)$/ ) {
  $password = $1;
  print "<I>(login disabled)</I> ";
}
if ( $conf->exists('showpasswords') ) {
  print "<B>$password</B>";
} else {
  print "<I>(hidden)</I>";
}
$password = '';

$svc_acct_pop = qsearchs('svc_acct_pop',{'popnum'=>$svc_acct->popnum});
print "<BR>POP: <B>", $svc_acct_pop->city, ", ", $svc_acct_pop->state,
      " (", $svc_acct_pop->ac, ")/", $svc_acct_pop->exch, "</B>"
  if $svc_acct_pop;

if ($svc_acct->uid ne '') {
  print "<BR><BR>Uid: <B>", $svc_acct->uid, "</B>",
        "<BR>Gid: <B>", $svc_acct->gid, "</B>",
        "<BR>Finger name: <B>", $svc_acct->finger, "</B>",
        "<BR>Home directory: <B>", $svc_acct->dir, "</B>",
        "<BR>Shell: <B>", $svc_acct->shell, "</B>",
        "<BR>Quota: <B>", $svc_acct->quota, "</B> <I>(unimplemented)</I>"
  ;
} else {
  print "<BR><BR>(No shell account)";
}

if ($svc_acct->slipip) {
  print "<BR><BR>IP address: <B>", ( $svc_acct->slipip eq "0.0.0.0" || $svc_acct->slipip eq '0e0' ) ? "<I>(Dynamic)</I>" : $svc_acct->slipip ,"</B>";
  my($attribute);
  foreach $attribute ( grep /^radius_/, fields('svc_acct') ) {
    #warn $attribute;
    $attribute =~ /^radius_(.*)$/;
    my $pattribute = $FS::raddb::attrib{$1};
    print "<BR>Radius (reply) $pattribute: <B>". $svc_acct->getfield($attribute), "</B>";
  }
  foreach $attribute ( grep /^rc_/, fields('svc_acct') ) {
    #warn $attribute;
    $attribute =~ /^rc_(.*)$/;
    my $pattribute = $FS::raddb::attrib{$1};
    print "<BR>Radius (check) $pattribute: <B>". $svc_acct->getfield($attribute), "</B>";
  }
} else {
  print "<BR><BR>(No SLIP/PPP account)";
}

print "</BODY></HTML>";

%>
