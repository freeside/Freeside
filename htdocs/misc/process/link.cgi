#!/usr/bin/perl -Tw
#
# $Id: link.cgi,v 1.2 1998-12-17 09:15:00 ivan Exp $
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
# Revision 1.2  1998-12-17 09:15:00  ivan
# s/CGI::Request/CGI.pm/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::CGI qw(popurlidiot);
use FS::UID qw(cgisuidsetup);
use FS::cust_svc;
use FS::Record qw(qsearchs);

my($cgi)=new CGI;
cgisuidsetup($cgi);

$cgi->param('pkgnum') =~ /^(\d+)$/; my($pkgnum)=$1;
$cgi->param('svcpart') =~ /^(\d+)$/; my($svcpart)=$1;

$cgi->param('svcnum') =~ /^(\d*)$/; my($svcnum)=$1;
unless ( $svcnum ) {
  my($part_svc) = qsearchs('part_svc',{'svcpart'=>$svcpart});
  my($svcdb) = $part_svc->getfield('svcdb');
  $cgi->param('link_field') =~ /^(\w+)$/; my($link_field)=$1;
  my($svc_acct)=qsearchs($svcdb,{$link_field => $cgi->param('link_value') });
  idiot("$link_field not found!") unless $svc_acct;
  $svcnum=$svc_acct->svcnum;
}

my($old)=qsearchs('cust_svc',{'svcnum'=>$svcnum});
die "svcnum not found!" unless $old;
my($new)=create FS::cust_svc ({
  'svcnum' => $svcnum,
  'pkgnum' => $pkgnum,
  'svcpart' => $svcpart,
});

my($error);
$error = $new->replace($old);

unless ($error) {
  #no errors, so let's view this customer.
  print $cgi->redirect(popurl(3). "view/cust_pkg.cgi?$pkgnum");
} else {
  idiot($error);
}

