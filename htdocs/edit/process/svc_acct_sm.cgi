#!/usr/bin/perl -Tw
#
# process/svc_acct_sm.cgi: Add/edit a mail alias (process form)
#
# Usage: post form to:
#        http://server.name/path/svc_acct_sm.cgi
#
# Note: Should br run setuid root as user nobody.
#
# lots of crufty stuff from svc_acct still in here, and modifications are (unelegantly) disabled.
#
# ivan@voicenet.com 97-jan-6
#
# enabled modifications
# 
# ivan@voicenet.com 97-may-7
#
# fixed removal of cust_svc record on modifications!
# ivan@voicenet.com 97-jun-5
#
# rewrite ivan@sisd.com 98-mar-15
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::svc_acct_sm;

my($req)=new CGI::Request; # create form object
cgisuidsetup($req->cgi);

$req->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($svcnum)=$1;

my($old)=qsearchs('svc_acct_sm',{'svcnum'=>$svcnum}) if $svcnum;

#unmunge domsvc and domuid
$req->param('domsvc',(split(/:/, $req->param('domsvc') ))[0] );
$req->param('domuid',(split(/:/, $req->param('domuid') ))[0] );

my($new) = create FS::svc_acct_sm ( {
  map {
    ($_, scalar($req->param($_)));
  } qw(svcnum pkgnum svcpart domuser domuid domsvc)
} );

my($error);
if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->getfield('svcnum');
} 

unless ($error) {
  $req->cgi->redirect("../../view/svc_acct_sm.cgi?$svcnum");
} else {
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error adding/editing mail alias</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error adding/editing mail alias</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and submit the form again.
  </BODY>
</HTML>
END

}

