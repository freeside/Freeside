#!/usr/bin/perl -Tw
#
# process/svc_acct.cgi: Add/edit a customer (process form)
#
# Usage: post form to:
#        http://server.name/path/svc_acct.cgi
#
# Note: Should br run setuid root as user nobody.
#
# ivan@voicenet.com 96-dec-18
#
# Changed /u to /u2
# ivan@voicenet.com 97-may-6
#
# rewrote for new API
# ivan@voicenet.com 97-jul-17 - 21
#
# no FS::Search, FS::svc_acct creates FS::cust_svc record, used for adding
# and editing ivan@sisd.com 98-mar-8
#
# Changes to allow page to work at a relative position in server
# Changed 'password' to '_password' because Pg6.3 reserves the password word
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::svc_acct;

my($req) = new CGI::Request; # create form object
&cgisuidsetup($req->cgi);

$req->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($svcnum)=$1;

my($old)=qsearchs('svc_acct',{'svcnum'=>$svcnum}) if $svcnum;

#unmunge popnum
$req->param('popnum', (split(/:/, $req->param('popnum') ))[0] );

#unmunge passwd
if ( $req->param('_password') eq '*HIDDEN*' ) {
  $req->param('_password',$old->getfield('_password'));
}

my($new) = create FS::svc_acct ( {
  map {
    $_, $req->param($_);
  } qw(svcnum pkgnum svcpart username _password popnum uid gid finger dir
    shell quota slipip)
} );

if ( $svcnum ) {
  my($error) = $new->replace($old);
  &idiot($error) if $error;
} else {
  my($error) = $new->insert;
  &idiot($error) if $error;
  $svcnum = $new->getfield('svcnum');
}

#no errors, view account
$req->cgi->redirect("../../view/svc_acct.cgi?" . $svcnum );

sub idiot {
  my($error)=@_;
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error adding/updating account</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error adding/updating account</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and submit the form again.
  </BODY>
</HTML>
END
  exit;
}

