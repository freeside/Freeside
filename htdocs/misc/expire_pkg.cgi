#!/usr/bin/perl -Tw
#
# $Id: expire_pkg.cgi,v 1.2 1998-12-17 09:12:44 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/expire_pkg.cgi
#
# Note: Should be run setuid freeside as user nobody
#
# based on susp_pkg
# ivan@voicenet.com 97-jul-29
#
# ivan@sisd.com 98-mar-17 FS::Search->FS::Record
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
# 
# $Log: expire_pkg.cgi,v $
# Revision 1.2  1998-12-17 09:12:44  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use Date::Parse;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl eidiot);
use FS::Record qw(qsearchs);
use FS::cust_pkg;

my($cgi) = new CGI;
&cgisuidsetup($cgi);

#untaint date & pkgnum

my($date);
if ( $cgi->param('date') ) {
  str2time($cgi->param('date')) =~ /^(\d+)$/ or die "Illegal date";
  $date=$1;
} else {
  $date='';
}

$cgi->param('pkgnum') =~ /^(\d+)$/ or die "Illegal pkgnum";
my($pkgnum)=$1;

my($cust_pkg) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
my(%hash)=$cust_pkg->hash;
$hash{expire}=$date;
my($new)=create FS::cust_pkg ( \%hash );
my($error) = $new->replace($cust_pkg);
&eidiot($error) if $error;

print $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

