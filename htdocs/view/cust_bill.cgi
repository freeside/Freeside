#!/usr/bin/perl -Tw
#
# Usage: cust_bill.cgi invnum
#        http://server.name/path/cust_bill.cgi?invnum
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

use strict;
use IO::File;
use CGI::Base qw(:DEFAULT :CGI); # CGI module
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::Invoice;

my($cgi) = new CGI::Base;
$cgi->get;
&cgisuidsetup($cgi);

#untaint invnum
$QUERY_STRING =~ /^(\d+)$/;
my($invnum)=$1;

my($cust_bill) = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;
my($custnum) = $cust_bill->getfield('custnum');

my($printed) = $cust_bill->printed;

SendHeaders(); # one guess.
print <<END;
<HTML>
  <HEAD>
    <TITLE>Invoice View</TITLE>
  </HEAD>
  <BODY>
    <CENTER>
    <H1>Invoice View</H1>
    <A HREF="../view/cust_main.cgi?$custnum">View this customer (#$custnum)</A> | <A HREF="../">Main menu</A>
    </CENTER><HR>
    <BASEFONT SIZE=3>
    <CENTER>
      <A HREF="../edit/cust_pay.cgi?$invnum">Enter payments (check/cash) against this invoice</A>
      <BR><A HREF="../misc/print-invoice.cgi?$invnum">Reprint this invoice</A>
      <BR><BR>(Printed $printed times)
    </CENTER>
    <FONT SIZE=-1><PRE>
END

bless($cust_bill,"FS::Invoice");
print $cust_bill->print_text;

	#formatting
	print <<END;
    </PRE></FONT>
  </BODY>
</HTML>
END

