<!-- mason kludge -->
<%

print header("Pending credit card batch", menubar(
  'Main Menu' => $p,
#  'Add new referral' => "../edit/part_referral.cgi",
)), &table(), <<END;
      <TR>
        <TH>#</TH>
        <TH><font size=-1>inv#</font></TH>
        <TH COLSPAN=2>Customer</TH>
        <TH>Card name</TH>
        <TH>Card</TH>
        <TH>Exp</TH>
        <TH>Amount</TH>
      </TR>
END

foreach my $cust_pay_batch ( sort { 
  $a->getfield('paybatchnum') <=> $b->getfield('paybatchnum')
} qsearch('cust_pay_batch',{}) ) {
#  my $date = time2str( "%a %b %e %T %Y", $queue->_date );
#  my $status = $hashref->{status};
#  if ( $status eq 'failed' || $status eq 'locked' ) {
#    $status .=
#      qq! ( <A HREF="$p/edit/cust_pay_batch.cgi?jobnum=$jobnum&action=new">retry</A> |!.
#      qq! <A HREF="$p/edit/cust_pay_batch.cgi?jobnum$jobnum&action=del">remove </A> )!;
#  }
  my $cardnum = $cust_pay_batch->{cardnum};
  $cardnum =~ s/.{4}$/xxxx/;
  print <<END;
      <TR>
        <TD>$cust_pay_batch->{paybatchnum}</TD>
        <TD><A HREF="../view/cust_bill.cgi?$cust_pay_batch->{invnum}">$cust_pay_batch->{invnum}</TD>
        <TD><A HREF="../view/cust_main.cgi?$cust_pay_batch->{custnum}">$cust_pay_batch->{custnum}</TD>
        <TD>$cust_pay_batch->{last}, $cust_pay_batch->{last}</TD>
        <TD>$cust_pay_batch->{payname}</TD>
        <TD>$cardnum</TD>
        <TD>$cust_pay_batch->{exp}</TD>
        <TD align="right">\$$cust_pay_batch->{amount}</TD>
      </TR>
END

}

print <<END;
    </TABLE>
  </BODY>
</HTML>
END

%>
