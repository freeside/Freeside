#!/usr/bin/perl -Tw
#
# process/link.cgi: link to existing customer (process form)
#
# ivan@voicenet.com 97-feb-5
#
# rewrite ivan@sisd.com 98-mar-18
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# can also link on some other fields now (about time) ivan@sisd.com 98-jun-24

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::CGI qw(idiot);
use FS::UID qw(cgisuidsetup);
use FS::cust_svc;
use FS::Record qw(qsearchs);

my($req)=new CGI::Request; # create form object
cgisuidsetup($req->cgi);

#$req->import_names('R'); #import CGI variables into package 'R';

$req->param('pkgnum') =~ /^(\d+)$/; my($pkgnum)=$1;
$req->param('svcpart') =~ /^(\d+)$/; my($svcpart)=$1;

$req->param('svcnum') =~ /^(\d*)$/; my($svcnum)=$1;
unless ( $svcnum ) {
  my($part_svc) = qsearchs('part_svc',{'svcpart'=>$svcpart});
  my($svcdb) = $part_svc->getfield('svcdb');
  $req->param('link_field') =~ /^(\w+)$/; my($link_field)=$1;
  my($svc_acct)=qsearchs($svcdb,{$link_field => $req->param('link_value') });
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
  $req->cgi->redirect("../../view/cust_pkg.cgi?$pkgnum");
} else {
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and submit the form again.
  </BODY>
</HTML>
END
 
}

