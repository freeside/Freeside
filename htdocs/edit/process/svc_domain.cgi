#!/usr/bin/perl -Tw
#
# $Id: svc_domain.cgi,v 1.3 1999-01-18 22:48:02 ivan Exp $
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
#
# $Log: svc_domain.cgi,v $
# Revision 1.3  1999-01-18 22:48:02  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.2  1998/12/17 08:40:30  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::svc_domain;

#remove this to actually test the domains!
$FS::svc_domain::whois_hack = 1;

my($cgi) = new CGI;
&cgisuidsetup($cgi);

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($svcnum)=$1;

my($new) = new FS::svc_domain ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(svcnum pkgnum svcpart domain action purpose)
  } ( fields('svc_domain'), qw( pkgnum svcpart action purpose ) )
} );

my($error);
if ($cgi->param('legal') ne "Yes") {
  $error = "Customer did not agree to be bound by NSI's ".
    qq!<A HREF="http://rs.internic.net/help/agreement.txt">!.
    "Domain Name Resgistration Agreement</A>";
} elsif ($cgi->param('svcnum')) {
  $error="Can't modify a domain!";
} else {
  $error=$new->insert;
  $svcnum=$new->svcnum;
}

unless ($error) {
  print $cgi->redirect(popurl(3). "view/svc_domain.cgi?$svcnum");
} else {
  idiot($error);
}

