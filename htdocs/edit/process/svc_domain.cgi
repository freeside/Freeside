#!/usr/bin/perl -Tw
#
# process/svc_domain.cgi: Add a domain (process form)
#
# Usage: post form to:
#        http://server.name/path/svc_domain.cgi
#
# Note: Should br run setuid root as user nobody.
#
# lots of yucky stuff in this one... bleachlkjhui!
#
# ivan@voicenet.com 97-jan-6
#
# kludged for new domain template 3.5
# ivan@voicenet.com 97-jul-24
#
# moved internic bits to svc_domain.pm ivan@sisd.com 98-mar-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::svc_domain;

#remove this to actually test the domains!
$FS::svc_domain::whois_hack = 1;

my($req) = new CGI::Request;
&cgisuidsetup($req->cgi);

$req->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($svcnum)=$1;

my($new) = create FS::svc_domain ( {
  map {
    $_, $req->param($_);
  } qw(svcnum pkgnum svcpart domain action purpose)
} );

my($error);
if ($req->param('legal') ne "Yes") {
  $error = "Customer did not agree to be bound by NSI's ".
    qq!<A HREF="http://rs.internic.net/help/agreement.txt">!.
    "Domain Name Resgistration Agreement</A>";
} elsif ($req->param('svcnum')) {
  $error="Can't modify a domain!";
} else {
  $error=$new->insert;
  $svcnum=$new->svcnum;
}

unless ($error) {
  $req->cgi->redirect("../../view/svc_domain.cgi?$svcnum");
} else {
  CGI::Base::SendHeaders(); # one guess
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error adding domain</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H4>Error adding domain</H4>
    </CENTER>
    Your update did not occur because of the following error:
    <P><B>$error</B>
    <P>Hit the <I>Back</I> button in your web browser, correct this mistake, and submit the form again.
  </BODY>
</HTML>
END

}


