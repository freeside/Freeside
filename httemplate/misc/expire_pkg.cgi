<%
#<!-- $Id: expire_pkg.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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

%>
