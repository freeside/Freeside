<%
#<!-- $Id: bill.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

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
