#!/usr/bin/perl -Tw
#
# $Id: cust_bill.cgi,v 1.2 1998-12-17 09:41:07 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_bill.cgi
#
# Note: Should be run setuid freeside as user nobody.
#
# ivan@voicenet.com 97-apr-4
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cust_bill.cgi,v $
# Revision 1.2  1998-12-17 09:41:07  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl idiot);
use FS::Record qw(qsearchs);

my($cgi)=new CGI;
cgisuidsetup($cgi);

$cgi->param('invnum') =~ /^\s*(FS-)?(\d+)\s*$/;
my($invnum)=$2;

if ( qsearchs('cust_bill',{'invnum'=>$invnum}) ) {
  print $cgi->redirect(popurl(2). "view/cust_bill.cgi?$invnum");  #redirect
} else { #error
  idiot("Invoice not found.");
}

