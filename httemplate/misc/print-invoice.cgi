<%
#
# $Id: print-invoice.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# just a kludge for now, since this duplicates in a way it shouldn't stuff from
# Bill.pm (like $lpr) ivan@sisd.com 98-jun-16
#
# $Log: print-invoice.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.4  1999/01/19 05:14:07  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.3  1998/12/23 03:04:24  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:12:47  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

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
