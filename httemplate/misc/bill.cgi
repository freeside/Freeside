<%
#
# $Id: bill.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# s/FS:Search/FS::Record/ and cgisuidsetup($cgi) ivan@sisd.com 98-mar-13
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: bill.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.5  1999/08/12 04:32:21  ivan
# hidecancelledcustomers
#
# Revision 1.4  1999/01/19 05:14:02  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1998/12/23 03:01:13  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:12:41  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use vars qw( $cgi $query $custnum $cust_main $error );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl eidiot);
use FS::Record qw(qsearchs);
use FS::cust_main;

$cgi = new CGI;
&cgisuidsetup($cgi);

#untaint custnum
($query) = $cgi->keywords;
$query =~ /^(\d*)$/;
$custnum = $1;
$cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
die "Can't find customer!\n" unless $cust_main;

$error = $cust_main->bill(
#                          'time'=>$time
                         );
&eidiot($error) if $error;

$error = $cust_main->collect(
#                             'invoice-time'=>$time,
#                             'batch_card'=> 'yes',
                             'batch_card'=> 'no',
                             'report_badcard'=> 'yes',
                            );
&eidiot($error) if $error;

print $cgi->redirect(popurl(2). "view/cust_main.cgi?$custnum");

%>
