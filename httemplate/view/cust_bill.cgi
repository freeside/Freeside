<!-- $Id: cust_bill.cgi,v 1.7 2002-02-04 16:44:47 ivan Exp $ -->
<%

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $invnum = $1;

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;
my $custnum = $cust_bill->getfield('custnum');

#my $printed = $cust_bill->printed;

print header('Invoice View', menubar(
  "Main Menu" => $p,
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
));

print qq!<A HREF="${p}edit/cust_pay.cgi?$invnum">Enter payments (check/cash) against this invoice</A> | !
  if $cust_bill->owed > 0;

print qq!<A HREF="${p}misc/print-invoice.cgi?$invnum">Reprint this invoice</A>!.
#     "<BR><BR>(Printed $printed times)".
#print cust_bill_events
      '<PRE>'.

print $cust_bill->print_text;

	#formatting
	print <<END;
    </PRE></FONT>
  </BODY>
</HTML>
END

%>
