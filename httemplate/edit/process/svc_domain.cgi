<%
#<!-- $Id: svc_domain.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $svcnum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs fields);
use FS::svc_domain;
use FS::CGI qw(popurl);

#remove this to actually test the domains!
$FS::svc_domain::whois_hack = 1;

$cgi = new CGI;
&cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
$svcnum = $1;

$new = new FS::svc_domain ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(svcnum pkgnum svcpart domain action purpose)
  } ( fields('svc_domain'), qw( pkgnum svcpart action purpose ) )
} );

if ($cgi->param('svcnum')) {
  $error="Can't modify a domain!";
} else {
  $error=$new->insert;
  $svcnum=$new->svcnum;
}

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "svc_domain.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum");
}

%>
