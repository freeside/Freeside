<!-- mason kludge -->
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

print qq!<A HREF="${p}misc/print-invoice.cgi?$invnum">Reprint this invoice</A>!;
if ( grep { $_ ne 'POST' } $cust_bill->cust_main->invoicing_list ) {
  print qq! | <A HREF="${p}misc/email-invoice.cgi?$invnum">!.
        qq!Re-email this invoice</A>!;
}

print '<BR><BR>';

my $conf = new FS::Conf;
if ( $conf->exists('invoice_latex') ) {
  print menubar(
    'View typeset invoice' => "${p}view/cust_bill-pdf.cgi?$invnum",
  ), '<BR><BR>';
}

#false laziness with search/cust_bill_event.cgi

print table(). '<TR><TH>Event</TH><TH>Date</TH><TH>Status</TH></TR>';
foreach my $cust_bill_event (
  sort { $a->_date <=> $b->_date } $cust_bill->cust_bill_event
) {
  my $status = $cust_bill_event->status;
  $status .= ': '. $cust_bill_event->statustext if $cust_bill_event->statustext;
  print '<TR><TD>'. $cust_bill_event->part_bill_event->event. '</TD><TD>'.
        time2str("%a %b %e %T %Y", $cust_bill_event->_date). '</TD><TD>'.
        $status. '</TD></TR>';
}
print '</TABLE><BR><PRE>';

print $cust_bill->print_text;

	#formatting
	print <<END;
    </PRE></FONT>
  </BODY>
</HTML>
END

%>
