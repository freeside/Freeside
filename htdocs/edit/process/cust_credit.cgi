#!/usr/bin/perl -Tw
#
# $Id: cust_credit.cgi,v 1.6 1999-02-28 00:03:41 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_credit.cgi
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
# Revision 1.6  1999-02-28 00:03:41  ivan
# removed misleading comments
#
# Revision 1.5  1999/01/25 12:09:59  ivan
# yet more mod_perl stuff
#
# Revision 1.4  1999/01/19 05:13:49  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1999/01/18 22:47:51  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.2  1998/12/17 08:40:18  ivan
# s/CGI::Request/CGI.pm/; etc
#

use strict;
use vars qw( $cgi $custnum $new $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw(popurl);
use FS::Record qw(fields);
use FS::cust_credit;

$cgi = new CGI;
cgisuidsetup($cgi);

$cgi->param('custnum') =~ /^(\d*)$/ or die "Illegal custnum!";
$custnum = $1;

$cgi->param('otaker',getotaker);

$new = new FS::cust_credit ( {
  map {
    $_, scalar($cgi->param($_));
  #} qw(custnum _date amount otaker reason)
  } fields('cust_credit')
} );

$error=$new->insert;

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_credit.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum#history");
}


