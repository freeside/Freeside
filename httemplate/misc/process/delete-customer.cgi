<%
#
# $Id: delete-customer.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# $Log: delete-customer.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.1  1999/04/15 16:44:36  ivan
# delete customers
#

use strict;
use vars qw ( $cgi $conf $custnum $new_custnum $cust_main $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::CGI qw(popurl);
use FS::cust_main;

$cgi = new CGI;
cgisuidsetup($cgi);

$conf = new FS::Conf;
die "Customer deletions not enabled" unless $conf->exists('deletecustomers');

$cgi->param('custnum') =~ /^(\d+)$/;
$custnum = $1;
if ( $cgi->param('new_custnum') ) {
  $cgi->param('new_custnum') =~ /^(\d+)$/
    or die "Illegal new customer number: ". $cgi->param('new_custnum');
  $new_custnum = $1;
} else {
  $new_custnum = '';
}
$cust_main = qsearchs( 'cust_main', { 'custnum' => $custnum } )
  or die "Customer not found: $custnum";

$error = $cust_main->delete($new_custnum);

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "delete-customer.cgi?". $cgi->query_string );
} elsif ( $new_custnum ) {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$new_custnum");
} else {
  print $cgi->redirect(popurl(3));
}
%>
