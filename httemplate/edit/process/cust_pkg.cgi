<%
#<!-- $Id: cust_pkg.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw( $cgi $custnum @remove_pkgnums @pkgparts $pkgpart $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::cust_pkg;

$cgi = new CGI; # create form object
&cgisuidsetup($cgi);
$error = '';

#untaint custnum
$cgi->param('custnum') =~ /^(\d+)$/;
$custnum = $1;

@remove_pkgnums = map {
  /^(\d+)$/ or die "Illegal remove_pkg value!";
  $1;
} $cgi->param('remove_pkg');

foreach $pkgpart ( map /^pkg(\d+)$/ ? $1 : (), $cgi->param ) {
  if ( $cgi->param("pkg$pkgpart") =~ /^(\d+)$/ ) {
    my $num_pkgs = $1;
    while ( $num_pkgs-- ) {
      push @pkgparts,$pkgpart;
    }
  } else {
    $error = "Illegal quantity";
    last;
  }
}

$error ||= FS::cust_pkg::order($custnum,\@pkgparts,\@remove_pkgnums);

if ($error) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_pkg.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
}

%>
