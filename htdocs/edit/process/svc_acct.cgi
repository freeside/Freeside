#!/usr/bin/perl -Tw
#
# $Id: svc_acct.cgi,v 1.5 1999-02-07 09:59:30 ivan Exp $
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
# Revision 1.5  1999-02-07 09:59:30  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.4  1999/01/19 05:13:58  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1999/01/18 22:47:59  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.2  1998/12/17 08:40:27  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use vars qw( $cgi $svcnum $old $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(qsearchs fields);
use FS::svc_acct;

$cgi = new CGI;
&cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
$svcnum = $1;

$old = qsearchs('svc_acct',{'svcnum'=>$svcnum}) if $svcnum;

#unmunge popnum
$cgi->param('popnum', (split(/:/, $cgi->param('popnum') ))[0] );

#unmunge passwd
if ( $cgi->param('_password') eq '*HIDDEN*' ) {
  $cgi->param('_password',$old->getfield('_password'));
}

$new = new FS::svc_acct ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(svcnum pkgnum svcpart username _password popnum uid gid finger dir
  #  shell quota slipip)
  } ( fields('svc_acct'), qw( pkgnum svcpart ) )
} );

if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->svcnum;
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "svc_acct.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/svc_acct.cgi?" . $svcnum );
}

