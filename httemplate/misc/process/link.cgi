<%
#<!-- $Id: link.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw ( $cgi $old $new $error $pkgnum $svcpart $svcnum );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::CGI qw(popurl idiot eidiot);
use FS::UID qw(cgisuidsetup);
use FS::cust_svc;
use FS::Record qw(qsearchs);

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('pkgnum') =~ /^(\d+)$/;
$pkgnum = $1;
$cgi->param('svcpart') =~ /^(\d+)$/;
$svcpart = $1;
$cgi->param('svcnum') =~ /^(\d*)$/;
$svcnum = $1;

unless ( $svcnum ) {
  my($part_svc) = qsearchs('part_svc',{'svcpart'=>$svcpart});
  my($svcdb) = $part_svc->getfield('svcdb');
  $cgi->param('link_field') =~ /^(\w+)$/; my($link_field)=$1;
  my($svc_acct)=qsearchs($svcdb,{$link_field => $cgi->param('link_value') });
  eidiot("$link_field not found!") unless $svc_acct;
  $svcnum=$svc_acct->svcnum;
}

$old = qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "svcnum not found!" unless $old;
$new = new FS::cust_svc ({
  'svcnum' => $svcnum,
  'pkgnum' => $pkgnum,
  'svcpart' => $svcpart,
});

$error = $new->replace($old);

unless ($error) {
  #no errors, so let's view this customer.
  print $cgi->redirect(popurl(3). "view/cust_pkg.cgi?$pkgnum");
} else {
  idiot($error);
}

%>
