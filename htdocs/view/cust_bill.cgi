#!/usr/bin/perl -Tw
#
# $Id: cust_bill.cgi,v 1.5 1999-01-18 09:41:42 ivan Exp $
#
# Note: Should be run setuid freeside as user nobody.
#
# this is a quick & ugly hack which does little more than add some formatting to the ascii output from /dbin/print-invoice
#
# ivan@voicenet.com 96-dec-05
#
# added navigation bar
# ivan@voicenet.com 97-jan-30
#
# now uses Invoice.pm
# ivan@voicenet.com 97-jun-30
#
# what to do if cust_bill search errors?
# ivan@voicenet.com 97-jul-7
#
# s/FS::Search/FS::Record/; $cgisuidsetup($cgi); ivan@sisd.com 98-mar-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# also print 'printed' field ivan@sisd.com 98-jul-10
#
# $Log: cust_bill.cgi,v $
# Revision 1.5  1999-01-18 09:41:42  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.4  1998/12/30 23:03:33  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.3  1998/12/23 03:07:49  ivan
# $cgi->keywords instead of $cgi->query_string
#
# Revision 1.2  1998/12/17 09:57:20  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#

use strict;
use IO::File;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl menubar);
use FS::Record qw(qsearchs);
use FS::cust_bill;

my($cgi) = new CGI;
&cgisuidsetup($cgi);

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my($invnum)=$1;

my($cust_bill) = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;
my($custnum) = $cust_bill->getfield('custnum');

my($printed) = $cust_bill->printed;

my $p = popurl(2);
print $cgi->header( '-expires' => 'now' ), header('Invoice View', menubar(
  "Main Menu" => $p,
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
)), <<END;
      <A HREF="${p}edit/cust_pay.cgi?$invnum">Enter payments (check/cash) against this invoice</A>
      <BR><A HREF="${p}misc/print-invoice.cgi?$invnum">Reprint this invoice</A>
      <BR><BR>(Printed $printed times)
    <FONT SIZE=-1><PRE>
END

print $cust_bill->print_text;

	#formatting
	print <<END;
    </PRE></FONT>
  </BODY>
</HTML>
END

