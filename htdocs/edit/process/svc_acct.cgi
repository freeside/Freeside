#!/usr/bin/perl -Tw
#
# $Id: svc_acct.cgi,v 1.2 1998-12-17 08:40:27 ivan Exp $
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
#
# $Log: svc_acct.cgi,v $
# Revision 1.2  1998-12-17 08:40:27  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(eidiot popurl);
use FS::Record qw(qsearchs);
use FS::svc_acct;

my($cgi) = new CGI;
&cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($svcnum)=$1;

my($old)=qsearchs('svc_acct',{'svcnum'=>$svcnum}) if $svcnum;

#unmunge popnum
$cgi->param('popnum', (split(/:/, $cgi->param('popnum') ))[0] );

#unmunge passwd
if ( $cgi->param('_password') eq '*HIDDEN*' ) {
  $cgi->param('_password',$old->getfield('_password'));
}

my($new) = create FS::svc_acct ( {
  map {
    $_, scalar($cgi->param($_));
  } qw(svcnum pkgnum svcpart username _password popnum uid gid finger dir
    shell quota slipip)
} );

if ( $svcnum ) {
  my($error) = $new->replace($old);
  &eidiot($error) if $error;
} else {
  my($error) = $new->insert;
  &eidiot($error) if $error;
  $svcnum = $new->getfield('svcnum');
}

#no errors, view account
print $cgi->redirect(popurl(3). "view/svc_acct.cgi?" . $svcnum );


