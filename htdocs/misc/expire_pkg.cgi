#!/usr/bin/perl -Tw
#
# expire_pkg.cgi: Expire a package
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

use strict;
use Date::Parse;
use CGI::Request;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::cust_pkg;

my($req) = new CGI::Request;
&cgisuidsetup($req->cgi);

#untaint date & pkgnum

my($date);
if ( $req->param('date') ) {
  str2time($req->param('date')) =~ /^(\d+)$/ or die "Illegal date";
  $date=$1;
} else {
  $date='';
}

$req->param('pkgnum') =~ /^(\d+)$/ or die "Illegal pkgnum";
my($pkgnum)=$1;

my($cust_pkg) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
my(%hash)=$cust_pkg->hash;
$hash{expire}=$date;
my($new)=create FS::cust_pkg ( \%hash );
my($error) = $new->replace($cust_pkg);
&idiot($error) if $error;

$req->cgi->redirect("../view/cust_main.cgi?".$cust_pkg->getfield('custnum'));

sub idiot {
  my($error)=@_;
  SendHeaders();
  print <<END;
<HTML>
  <HEAD>
    <TITLE>Error expiring package</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>Error expiring package</H1>
    </CENTER>
    <HR>
    There has been an error expiring this package:  $error
  </BODY>
  </HEAD>
</HTML>
END
  exit;
}

