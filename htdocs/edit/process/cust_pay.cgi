#!/usr/bin/perl -Tw
#
# $Id: cust_pay.cgi,v 1.5 1999-01-19 05:13:53 ivan Exp $
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
# Revision 1.5  1999-01-19 05:13:53  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 22:47:54  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.3  1998/12/30 23:03:28  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.2  1998/12/17 08:40:22  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use vars qw( $cgi $invnum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(idiot popurl);
use FS::Record qw(fields);
use FS::cust_pay;

$cgi = new CGI;
&cgisuidsetup($cgi);

$cgi->param('invnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
$invnum = $1;

$new = new FS::cust_pay ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(invnum paid _date payby payinfo paybatch)
  } fields('cust_pay')
} );

$error=$new->insert;

if ($error) { #error!
  idiot($error);
} else { #no errors!
  print $cgi->redirect(popurl(3). "view/cust_bill.cgi?$invnum");
}

