#!/usr/bin/perl -Tw
#
# $Id: cust_credit.cgi,v 1.2 1998-12-17 08:40:18 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_credit.cgi
#
# Note: Should be run setuid root as user nobody.
#
# ivan@voicenet.com 96-dec-05 -> 96-dec-08
#
# post a refund if $new_paybatch
# ivan@voicenet.com 96-dec-08
#
# refunds are no longer applied against a specific payment (paybatch)
# paybatch field removed
# ivan@voicenet.com 97-apr-22
#
# rewrite ivan@sisd.com 98-mar-16
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cust_credit.cgi,v $
# Revision 1.2  1998-12-17 08:40:18  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(popurl eidiot);
use FS::cust_credit;

my($cgi)=new CGI; # create form object
cgisuidsetup($cgi);

$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
my($custnum)=$1;

$cgi->param('otaker',getotaker);

my($new) = create FS::cust_credit ( {
  map {
    $_, scalar($cgi->param($_));
  } qw(custnum _date amount otaker reason)
} );

my($error);
$error=$new->insert;
&eidiot($error) if $error;

#no errors, no refund, so view our credit.
print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum#history");

