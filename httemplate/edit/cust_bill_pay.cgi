<!-- mason kludge -->
<%

my($paynum, $amount, $invnum);
if ( $cgi->param('error') ) {
  $paynum = $cgi->param('paynum');
  $amount = $cgi->param('amount');
  $invnum = $cgi->param('invnum');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $paynum = $1;
  $amount = '';
  $invnum = '';
}

my $otaker = getotaker;

my $p1 = popurl(1);

print header("Apply Payment", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT><BR><BR>"
  if $cgi->param('error');
print <<END;
    <FORM ACTION="${p1}process/cust_bill_pay.cgi" METHOD=POST>
END

my $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } );
die "payment $paynum not found!" unless $cust_pay;

my $unapplied = $cust_pay->unapplied;

print "Payment # <B>$paynum</B>".
      qq!<INPUT TYPE="hidden" NAME="paynum" VALUE="$paynum">!.
      '<BR>Date: <B>'. time2str("%D", $cust_pay->_date). '</B>'.
      '<BR>Amount: $<B>'. $cust_pay->paid. '</B>'.
      "<BR>Unapplied amount: \$<B>$unapplied</B>"
      ;

my @cust_bill = grep $_->owed != 0,
                qsearch('cust_bill', { 'custnum' => $cust_pay->custnum } );

print <<END;
<SCRIPT>
function changed(what) {
  cust_bill = what.options[what.selectedIndex].value;
END

foreach my $cust_bill ( @cust_bill ) {
  my $invnum = $cust_bill->invnum;
  my $changeto = $cust_bill->owed < $unapplied
                   ? $cust_bill->owed 
                   : $unapplied;
  print <<END;
  if ( cust_bill == $invnum ) {
    what.form.amount.value = "$changeto";
  }
END
}

#  if ( cust_bill == "Refund" ) {
#    what.form.amount.value = "$credited";
#  }
print <<END;
}
</SCRIPT>
END

print qq!<BR>Invoice #<SELECT NAME="invnum" SIZE=1 onChange="changed(this)">!,
      '<OPTION VALUE="">';
foreach my $cust_bill ( @cust_bill ) {
  print '<OPTION'. ( $cust_bill->invnum eq $invnum ? ' SELECTED' : '' ).
        ' VALUE="'. $cust_bill->invnum. '">'. $cust_bill->invnum.
        ' -  '. time2str("%D",$cust_bill->_date).
        ' - $'. $cust_bill->owed;
}
#print qq!<OPTION VALUE="Refund">Refund!;
print "</SELECT>";

print qq!<BR>Amount \$<INPUT TYPE="text" NAME="amount" VALUE="$amount" SIZE=8 MAXLENGTH=8>!;

print <<END;
<BR>
<INPUT TYPE="submit" VALUE="Apply">
END

print <<END;

    </FORM>
  </BODY>
</HTML>
END

%>
