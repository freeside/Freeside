#!/usr/bin/perl -Tw
#
# $Id: cust_pay.cgi,v 1.2 1998-12-17 08:40:22 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_pay.cgi
#
# Note: Should be run setuid root as user nobody.
#
# ivan@voicenet.com 96-dec-11
#
# rewrite ivan@sisd.com 98-mar-16
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cust_pay.cgi,v $
# Revision 1.2  1998-12-17 08:40:22  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(idiot popurl);
use FS::cust_pay qw(fields);

my($cgi)=new CGI;
&cgisuidsetup($cgi);

$cgi->param('invnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my($invnum)=$1;

my($new) = create FS::cust_pay ( {
  map {
    $_, scalar($cgi->param($_));
  } qw(invnum paid _date payby payinfo paybatch)
} );

my($error);
$error=$new->insert;

if ($error) { #error!
  idiot($error);
} else { #no errors!
  print $cgi->redirect(popurl(3). "view/cust_bill.cgi?$invnum");
}

