<%
#
# $Id: link.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# ivan@voicenet.com 97-feb-5
#
# rewrite ivan@sisd.com 98-mar-18
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# can also link on some other fields now (about time) ivan@sisd.com 98-jun-24
#
# $Log: link.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.6  2000/07/17 17:59:33  ivan
# oops
#
# Revision 1.5  1999/04/15 14:09:17  ivan
# get rid of top-level my() variables
#
# Revision 1.4  1999/02/07 09:59:35  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.3  1999/01/19 05:14:10  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.2  1998/12/17 09:15:00  ivan
# s/CGI::Request/CGI.pm/;
#

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
