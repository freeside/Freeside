<!-- mason kludge -->
<%

my($crednum, $amount, $invnum);
if ( $cgi->param('error') ) {
  #$cust_credit_bill = new FS::cust_credit_bill ( {
  #  map { $_, scalar($cgi->param($_)) } fields('cust_credit_bill')
  #} );
  $crednum = $cgi->param('crednum');
  $amount = $cgi->param('amount');
  #$refund = $cgi->param('refund');
  $invnum = $cgi->param('invnum');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $crednum = $1;
  $amount = '';
  #$refund = 'yes';
  $invnum = '';
}

my $otaker = getotaker;

my $p1 = popurl(1);

print header("Apply Credit", '');
print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT><BR><BR>"
  if $cgi->param('error');
print <<END;
    <FORM ACTION="${p1}process/cust_credit_bill.cgi" METHOD=POST>
END

my $cust_credit = qsearchs('cust_credit', { 'crednum' => $crednum } );
die "credit $crednum not found!" unless $cust_credit;

my $credited = $cust_credit->credited;

print "Credit # <B>$crednum</B>".
      qq!<INPUT TYPE="hidden" NAME="crednum" VALUE="$crednum">!.
      '<BR>Date: <B>'. time2str("%D", $cust_credit->_date). '</B>'.
      '<BR>Amount: $<B>'. $cust_credit->amount. '</B>'.
      "<BR>Unapplied amount: \$<B>$credited</B>".
      '<BR>Reason: <B>'. $cust_credit->reason. '</B>'
      ;

my @cust_bill = grep $_->owed != 0,
                qsearch('cust_bill', { 'custnum' => $cust_credit->custnum } );

print <<END;
<SCRIPT>
function changed(what) {
  cust_bill = what.options[what.selectedIndex].value;
END

foreach my $cust_bill ( @cust_bill ) {
  my $invnum = $cust_bill->invnum;
  my $changeto = $cust_bill->owed < $cust_credit->credited
                   ? $cust_bill->owed 
                   : $cust_credit->credited;
  print <<END;
  if ( cust_bill == $invnum ) {
    what.form.amount.value = "$changeto";
  }
END
}

print <<END;
  if ( cust_bill == "Refund" ) {
    what.form.amount.value = "$credited";
  }
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
print qq!<OPTION VALUE="Refund">Refund!;
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
