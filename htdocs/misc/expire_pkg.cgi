#!/usr/bin/perl -Tw
#
# $Id: expire_pkg.cgi,v 1.4 1999-02-28 00:03:50 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/expire_pkg.cgi
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
# Revision 1.4  1999-02-28 00:03:50  ivan
# removed misleading comments
#
# Revision 1.3  1999/01/19 05:14:05  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.2  1998/12/17 09:12:44  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use vars qw ( $cgi $date $pkgnum $cust_pkg %hash $new $error );
use Date::Parse;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl eidiot);
use FS::Record qw(qsearchs);
use FS::cust_pkg;

$cgi = new CGI;
&cgisuidsetup($cgi);

#untaint date & pkgnum

if ( $cgi->param('date') ) {
  str2time($cgi->param('date')) =~ /^(\d+)$/ or die "Illegal date";
  $date=$1;
} else {
  $date='';
}

$cgi->param('pkgnum') =~ /^(\d+)$/ or die "Illegal pkgnum";
$pkgnum = $1;

$cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
%hash = $cust_pkg->hash;
$hash{expire}=$date;
$new = new FS::cust_pkg ( \%hash );
$error = $new->replace($cust_pkg);
&eidiot($error) if $error;

print $cgi->redirect(popurl(2). "view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

