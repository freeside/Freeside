#!/usr/bin/perl -Tw
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

use strict;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::part_pkg qw(fields);
use FS::pkg_svc;
use FS::CGI qw(eidiot);

my($req)=new CGI::Request; # create form object

&cgisuidsetup($req->cgi);

my($pkgpart)=$req->param('pkgpart');

my($old)=qsearchs('part_pkg',{'pkgpart'=>$pkgpart}) if $pkgpart;

my($new)=create FS::part_pkg ( {
  map {
    $_, $req->param($_);
  } fields('part_pkg')
} );

if ( $pkgpart ) {
  my($error)=$new->replace($old);
  eidiot($error) if $error;
} else {
  my($error)=$new->insert;
  eidiot($error) if $error;
  $pkgpart=$new->getfield('pkgpart');
}

my($part_svc);
foreach $part_svc (qsearch('part_svc',{})) {
# don't update non-changing records in part_svc (causing harmless but annoying
# "Records identical" errors). ivan@sisd.com 98-jan-19
  #my($quantity)=$req->param('pkg_svc'. $part_svc->getfield('svcpart')),
  my($quantity)=$req->param('pkg_svc'. $part_svc->svcpart) || 0,
  my($old_pkg_svc)=qsearchs('pkg_svc',{
    'pkgpart'  => $pkgpart,
    'svcpart'  => $part_svc->getfield('svcpart'),
  });
  my($old_quantity)=$old_pkg_svc ? $old_pkg_svc->quantity : 0;
  next unless $old_quantity != $quantity; #!here
  my($new_pkg_svc)=create FS::pkg_svc({
    'pkgpart'  => $pkgpart,
    'svcpart'  => $part_svc->getfield('svcpart'),
    #'quantity' => $req->param('pkg_svc'. $part_svc->getfield('svcpart')),
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

#$req->cgi->redirect("../../view/part_pkg.cgi?$pkgpart");
#$req->cgi->redirect("../../edit/part_pkg.cgi?$pkgpart");
$req->cgi->redirect("../../browse/part_pkg.cgi");

