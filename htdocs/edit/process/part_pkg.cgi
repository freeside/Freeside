#!/usr/bin/perl -Tw
#
# $Id: part_pkg.cgi,v 1.7 1999-01-19 05:13:55 ivan Exp $
#
# process/part_pkg.cgi: Edit package definitions (process form)
#
# ivan@sisd.com 97-dec-10
#
# don't update non-changing records in part_svc (causing harmless but annoying
# "Records identical" errors). ivan@sisd.com 98-feb-19
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# Added `|| 0 ' when getting quantity off web page ivan@sisd.com 98-jun-4
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_pkg.cgi,v $
# Revision 1.7  1999-01-19 05:13:55  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.6  1999/01/18 22:47:56  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.5  1998/12/30 23:03:29  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.4  1998/12/17 08:40:24  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.3  1998/11/21 07:17:58  ivan
# bugfix to work for regular aswell as custom pricing
#
# Revision 1.2  1998/11/15 13:16:15  ivan
# first pass as per-user custom pricing
#

use strict;
use vars qw( $cgi $pkgpart $old $new $part_svc );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(eidiot popurl);
use FS::Record qw(qsearch qsearchs fields);
use FS::part_pkg;
use FS::pkg_svc;
use FS::cust_pkg;

$cgi = new CGI;
&cgisuidsetup($cgi);

$pkgpart = $cgi->param('pkgpart');

$old = qsearchs('part_pkg',{'pkgpart'=>$pkgpart}) if $pkgpart;

$new = new FS::part_pkg ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_pkg')
} );

local $SIG{HUP} = 'IGNORE';
local $SIG{INT} = 'IGNORE';
local $SIG{QUIT} = 'IGNORE';
local $SIG{TERM} = 'IGNORE';
local $SIG{TSTP} = 'IGNORE';

if ( $pkgpart ) {
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
  $pkgpart=$new->getfield('pkgpart');
}

foreach $part_svc (qsearch('part_svc',{})) {
# don't update non-changing records in part_svc (causing harmless but annoying
# "Records identical" errors). ivan@sisd.com 98-jan-19
  #my($quantity)=$cgi->param('pkg_svc'. $part_svc->getfield('svcpart')),
  my($quantity)=$cgi->param('pkg_svc'. $part_svc->svcpart) || 0,
  my($old_pkg_svc)=qsearchs('pkg_svc',{
    'pkgpart'  => $pkgpart,
    'svcpart'  => $part_svc->getfield('svcpart'),
  });
  my($old_quantity)=$old_pkg_svc ? $old_pkg_svc->quantity : 0;
  next unless $old_quantity != $quantity; #!here
  my($new_pkg_svc)=new FS::pkg_svc({
    'pkgpart'  => $pkgpart,
    'svcpart'  => $part_svc->getfield('svcpart'),
    #'quantity' => $cgi->param('pkg_svc'. $part_svc->getfield('svcpart')),
    'quantity' => $quantity, 
  });
  if ($old_pkg_svc) {
    my($error)=$new_pkg_svc->replace($old_pkg_svc);
    eidiot($error) if $error;
  } else {
    my($error)=$new_pkg_svc->insert;
    eidiot($error) if $error;
  }
}

unless ( $cgi->param('pkgnum') && $cgi->param('pkgnum') =~ /^(\d+)$/ ) {
  print $cgi->redirect(popurl(3). "browse/part_pkg.cgi");
} else {
  my($old_cust_pkg) = qsearchs( 'cust_pkg', { 'pkgnum' => $1 } );
  my %hash = $old_cust_pkg->hash;
  $hash{'pkgpart'} = $pkgpart;
  my($new_cust_pkg) = new FS::cust_pkg \%hash;
  my $error = $new_cust_pkg->replace($old_cust_pkg);
  eidiot "Error modifying cust_pkg record: $error\n" if $error;
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?". $new_cust_pkg->custnum);
}


