#!/usr/bin/perl -Tw
#
# process/cust_pkg.cgi: Add/edit packages (process form)
#
# this is for changing packages around, not for editing things within the
# package
#
# Usage: post form to:
#        http://server.name/path/cust_pkg.cgi
#
# Note: Should be run setuid root as user nobody.
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

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::cust_pkg;

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

#untaint custnum
$req->param('new_custnum') =~ /^(\d+)$/;
my($custnum)=$1;

my(@remove_pkgnums) = map {
  /^(\d+)$/ or die "Illegal remove_pkg value!";
  $1;
} $req->param('remove_pkg');

my(@pkgparts);
my($pkgpart);
foreach $pkgpart ( map /^pkg(\d+)$/ ? $1 : (), $req->params ) {
  my($num_pkgs)=$req->param("pkg$pkgpart");
  while ( $num_pkgs-- ) {
    push @pkgparts,$pkgpart;
  }
}

my($error) = FS::cust_pkg::order($custnum,\@pkgparts,\@remove_pkgnums);

if ($error) {
  CGI::Base::SendHeaders();
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error updating packages</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error updating packages</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and submit the form again.
  </BODY>
</HTML>
END
} else {
  $req->cgi->redirect("../../view/cust_main.cgi?$custnum#cust_pkg");
}

