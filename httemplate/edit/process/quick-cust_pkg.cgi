<%
#<!-- $Id: quick-cust_pkg.cgi,v 1.3 2001-09-11 10:05:30 ivan Exp $ -->

use strict;
use vars qw( $cgi $custnum $pkgpart $error ); #@remove_pkgnums @pkgparts
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl eidiot);
use FS::cust_pkg;

$cgi = new CGI; # create form object
&cgisuidsetup($cgi);
$error = '';

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/
  or eidiot 'illegal custnum '. $cgi->param('custnum');
$custnum = $1;
$cgi->param('pkgpart') =~ /^(\d+)$/
  or eidiot 'illegal pkgpart '. $cgi->param('pkgpart');
$pkgpart = $1;

my @cust_pkg = ();
$error ||= FS::cust_pkg::order($custnum, [ $pkgpart ], [], \@cust_pkg, );

if ($error) {
  eidiot($error);
} else {
  print $cgi->redirect(popurl(3). "view/cust_pkg.cgi?". $cust_pkg[0]->pkgnum );
}

%>

