<%
#
# $Id: catchall.cgi,v 1.1 2001-08-19 15:53:35 jeff Exp $
#
# Usage: post form to:
#        http://server.name/path/catchall.cgi
#
# $Log: catchall.cgi,v $
# Revision 1.1  2001-08-19 15:53:35  jeff
# added user interface for svc_forward and vpopmail support
#
#

use strict;
use vars qw( $cgi $svcnum $old $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs fields);
use FS::svc_domain;
use FS::CGI qw(popurl);

$FS::svc_domain::whois_hack=1;

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
$svcnum =$1;

$old = qsearchs('svc_domain',{'svcnum'=>$svcnum}) if $svcnum;

$new = new FS::svc_domain ( {
  map {
    ($_, scalar($cgi->param($_)));
  } ( fields('svc_domain'), qw( pkgnum svcpart ) )
} );

$new->setfield('action' => 'M');

if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->getfield('svcnum');
} 

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "catchall.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum");
}

%>
