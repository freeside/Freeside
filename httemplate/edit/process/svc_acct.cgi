<%
#<!-- $Id: svc_acct.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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

if ( $svcnum ) {
  $old = qsearchs('svc_acct', { 'svcnum' => $svcnum } )
    or die "fatal: can't find account (svcnum $svcnum)!";
} else {
  $old = '';
}

#unmunge popnum
$cgi->param('popnum', (split(/:/, $cgi->param('popnum') ))[0] );

#unmunge passwd
if ( $cgi->param('_password') eq '*HIDDEN*' ) {
  die "fatal: no previous account to recall hidden password from!" unless $old;
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

%>
