#!/usr/bin/perl -Tw
#
# $Id: svc_acct_sm.cgi,v 1.2 1998-12-17 08:40:29 ivan Exp $
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
#
# $Log: svc_acct_sm.cgi,v $
# Revision 1.2  1998-12-17 08:40:29  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::svc_acct_sm;

my($cgi)=new CGI; # create form object
cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($svcnum)=$1;

my($old)=qsearchs('svc_acct_sm',{'svcnum'=>$svcnum}) if $svcnum;

#unmunge domsvc and domuid
$cgi->param('domsvc',(split(/:/, $cgi->param('domsvc') ))[0] );
$cgi->param('domuid',(split(/:/, $cgi->param('domuid') ))[0] );

my($new) = create FS::svc_acct_sm ( {
  map {
    ($_, scalar($cgi->param($_)));
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
  print $cgi->redirect(popurl(3). "view/svc_acct_sm.cgi?$svcnum");
} else {
  idiot($error);
}

