<%
#
# $Id: cust_pkg.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# this is for changing packages around, not for editing things within the
# package
#
# Usage: post form to:
#        http://server.name/path/cust_pkg.cgi
#
# ivan@voicenet.com 97-mar-21 - 97-mar-24
#
# rewrote for new API
# ivan@voicenet.com 97-jul-7 - 15
#
# &cgisuidsetup($cgi) ivan@sisd.com 98-mar-7
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cust_pkg.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.7  1999/04/07 15:24:06  ivan
# don't use anchor in redirect
#
# Revision 1.6  1999/02/28 00:03:44  ivan
# removed misleading comments
#
# Revision 1.5  1999/02/07 09:59:26  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.3  1999/01/19 05:13:54  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.2  1998/12/17 08:40:23  ivan
# s/CGI::Request/CGI.pm/; etc
#

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
