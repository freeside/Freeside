#!/usr/bin/perl -Tw
#
# $Id: svc_acct_sm.cgi,v 1.6 1999-02-28 00:03:46 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/svc_acct_sm.cgi
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
# Revision 1.6  1999-02-28 00:03:46  ivan
# removed misleading comments
#
# Revision 1.5  1999/02/07 09:59:32  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.4  1999/01/19 05:14:00  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1999/01/18 22:48:01  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.2  1998/12/17 08:40:29  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use vars qw( $cgi $svcnum $old $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs fields);
use FS::svc_acct_sm;
use FS::CGI qw(popurl);

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
$svcnum =$1;

$old = qsearchs('svc_acct_sm',{'svcnum'=>$svcnum}) if $svcnum;

#unmunge domsvc and domuid
#$cgi->param('domsvc',(split(/:/, $cgi->param('domsvc') ))[0] );
#$cgi->param('domuid',(split(/:/, $cgi->param('domuid') ))[0] );

$new = new FS::svc_acct_sm ( {
  map {
    ($_, scalar($cgi->param($_)));
  #} qw(svcnum pkgnum svcpart domuser domuid domsvc)
  } ( fields('svc_acct_sm'), qw( pkgnum svcpart ) )
} );

if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->getfield('svcnum');
} 

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "svc_acct_sm.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/svc_acct_sm.cgi?$svcnum");
}

