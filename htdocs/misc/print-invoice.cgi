#!/usr/bin/perl -Tw
#
# $Id: print-invoice.cgi,v 1.2 1998-12-17 09:12:47 ivan Exp $
#
# just a kludge for now, since this duplicates in a way it shouldn't stuff from
# Bill.pm (like $lpr) ivan@sisd.com 98-jun-16
#
# $Log: print-invoice.cgi,v $
# Revision 1.2  1998-12-17 09:12:47  ivan
# s/CGI::(Request|Base)/CGI.pm/;
#

use strict;
use vars qw($conf);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(qsearchs);
use FS::cust_bill;

my($cgi) = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
my $lpr = $conf->config('lpr');

#untaint invnum
$cgi->query_string =~ /^(\d*)$/;
my($invnum)=$1;
my($cust_bill)=qsearchs('cust_bill',{'invnum'=>$invnum});
die "Can't find invoice!\n" unless $cust_bill;

        open(LPR,"|$lpr") or die "Can't open $lpr: $!";
        print LPR $cust_bill->print_text; #( date )
        close LPR
          or die $! ? "Error closing $lpr: $!"
                       : "Exit status $? from $lpr";

my($custnum)=$cust_bill->getfield('custnum');

print $cgi->redirect(popurl(2). "view/cust_main.cgi?$custnum#history");

