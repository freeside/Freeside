<%
# <!-- $Id: cust_bill.cgi,v 1.4 2001-10-26 10:24:56 ivan Exp $ -->

use strict;
use vars qw ( $cgi $query $invnum $cust_bill $custnum $printed $p );
use IO::File;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl menubar);
use FS::Record qw(qsearchs);
use FS::cust_bill;

$cgi = new CGI;
&cgisuidsetup($cgi);

#untaint invnum
($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
$invnum = $1;

$cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;
$custnum = $cust_bill->getfield('custnum');

$printed = $cust_bill->printed;

$p = popurl(2);
print $cgi->header( @FS::CGI::header ), header('Invoice View', menubar(
  "Main Menu" => $p,
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
));

print qq!<A HREF="${p}edit/cust_pay.cgi?$invnum">Enter payments (check/cash) against this invoice</A> | !
  if $cust_bill->owed > 0;

print <<END;
      <A HREF="${p}misc/print-invoice.cgi?$invnum">Reprint this invoice</A>
      <BR><BR>(Printed $printed times)
    <PRE>
END

print $cust_bill->print_text;

	#formatting
	print <<END;
    </PRE></FONT>
  </BODY>
</HTML>
END

%>
