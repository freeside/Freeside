<%
#<!-- $Id: quick-cust_pkg.cgi,v 1.1 2001-09-04 14:44:07 ivan Exp $ -->

use strict;
use vars qw( $cgi $custnum $pkgpart $error ); #@remove_pkgnums @pkgparts
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::cust_pkg;

$cgi = new CGI; # create form object
&cgisuidsetup($cgi);
$error = '';

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/
  or die 'illegal custnum '. $cgi->param('custnum');
$custnum = $1;
$cgi->param('pkgpart') =~ /^(\d+)$/
  or die 'illegal pkgpart '. $cgi->param('pkgpart');
$pkgpart = $1;

my @cust_pkg = ();
$error ||= FS::cust_pkg::order($custnum, [ $pkgpart ], [], \@cust_pkg, );

if ($error) {
  eidiot($error);
} else {
  print $cgi->redirect(popurl(3). "view/cust_pkg.cgi?". $cust_pkg[0]->pkgnum );
}

%>

