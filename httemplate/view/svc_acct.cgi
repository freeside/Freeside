<%
#
# $Id: svc_acct.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# Usage: svc_acct.cgi svcnum
#        http://server.name/path/svc_acct.cgi?svcnum
#
# ivan@voicenet.com 96-dec-17
#
# added link to send info
# ivan@voicenet.com 97-jan-4
#
# added navigation bar and ability to change username, etc.
# ivan@voicenet.com 97-jan-30
#
# activate 800 service
# ivan@voicenet.com 97-feb-10
#
# modified navbar code (should be a subroutine?), added link to cancel account (only if not audited)
# ivan@voicenet.com 97-apr-16
#
# INCOMPLETELY rewrote some things for new API
# ivan@voicenet.com 97-jul-29
#
# FS::Search became FS::Record, use strict, etc. ivan@sisd.com 98-mar-9
#
# Changes to allow page to work at a relative position in server
# Changed 'password' to '_password' because Pg6.3 reserves the password word
#       bmccane@maxbaud.net     98-apr-3
#
# /var/spool/freeside/conf/domain ivan@sisd.com 98-jul-17
#
# displays arbitrary radius attributes ivan@sisd.com 98-aug-16
#
# $Log: svc_acct.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.12  2001/01/31 07:21:00  ivan
# fix tyops
#
# Revision 1.11  2000/12/03 20:25:20  ivan
# session monitor updates
#
# Revision 1.10  1999/04/14 11:27:06  ivan
# showpasswords config option to show passwords
#
# Revision 1.9  1999/04/08 12:00:19  ivan
# aesthetic update
#
# Revision 1.8  1999/02/28 00:04:02  ivan
# removed misleading comments
#
# Revision 1.7  1999/01/19 05:14:21  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.6  1999/01/18 09:41:45  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.5  1999/01/18 09:22:36  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.4  1998/12/23 03:09:19  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.3  1998/12/17 09:57:23  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#
# Revision 1.2  1998/12/16 05:24:29  ivan
# use FS::Conf;
#

use strict;
use vars qw( $conf $cgi $mydomain $query $svcnum $svc_acct $cust_svc $pkgnum
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

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
$mydomain = $conf->config('domain');

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
    my($pattribute) = ($1);
    $pattribute =~ s/_/-/g;
    print "<BR>Radius $pattribute: <B>". $svc_acct->getfield($attribute), "</B>";
  }
} else {
  print "<BR><BR>(No SLIP/PPP account)";
}

print "</BODY></HTML>";

%>
