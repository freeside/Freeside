<%
#<!-- $Id: svc_acct_sm.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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

%>
