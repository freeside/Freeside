<%
#<!-- $Id: svc_forward.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $svcnum $old $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs fields);
use FS::svc_forward;
use FS::CGI qw(popurl);

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
$svcnum =$1;

$old = qsearchs('svc_forward',{'svcnum'=>$svcnum}) if $svcnum;

$new = new FS::svc_forward ( {
  map {
    ($_, scalar($cgi->param($_)));
  } ( fields('svc_forward'), qw( pkgnum svcpart ) )
} );

if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->getfield('svcnum');
} 

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "svc_forward.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/svc_forward.cgi?$svcnum");
}

%>
