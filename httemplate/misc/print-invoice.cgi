<%
#<!-- $Id: print-invoice.cgi,v 1.2 2001-08-21 02:31:56 ivan Exp $ -->

use strict;
use vars qw($conf $cgi $lpr $query $invnum $cust_bill $custnum );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(qsearchs);
use FS::cust_bill;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
$lpr = $conf->config('lpr');

#untaint invnum
($query) = $cgi->keywords;
$query =~ /^(\d*)$/;
$invnum = $1;
$cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

        open(LPR,"|$lpr") or die "Can't open $lpr: $!";
        print LPR $cust_bill->print_text; #( date )
        close LPR
          or die $! ? "Error closing $lpr: $!"
                       : "Exit status $? from $lpr";

$custnum = $cust_bill->getfield('custnum');

print $cgi->redirect(popurl(2). "view/cust_main.cgi?$custnum#history");

%>
