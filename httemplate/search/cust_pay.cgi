<%

my $sortby;
my @cust_pay;
if ( $cgi->param('magic') && $cgi->param('magic') eq '_date' ) {

  my %search;
  if ( $cgi->param('payby') ) {
    $cgi->param('payby') =~ /^(CARD|CHEK|BILL)$/
      or die "illegal payby ". $cgi->param('payby');
    $search{'payby'} = $1;
  }

  #false laziness with cust_pkg.cgi
  my $range = '';
  if ( $cgi->param('beginning')
       && $cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/ ) {
    my $beginning = str2time($1);
    $range = " WHERE _date >= $beginning ";
  }
  if ( $cgi->param('ending')
            && $cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/ ) {
    my $ending = str2time($1) + 86400;
    $range .= ( $range ? ' AND ' : ' WHERE ' ). " _date <= $ending ";
  }
  $range =~ s/^\s*WHERE/ AND/ if scalar(keys %search) ;

  @cust_pay = qsearch('cust_pay', \%search, '', $range );

  $sortby = \*date_sort;

} else {

  $cgi->param('payinfo') =~ /^\s*(\d+)\s*$/ or die "illegal payinfo";
  my $payinfo = $1;

  $cgi->param('payby') =~ /^(\w+)$/ or die "illegal payby";
  my $payby = $1;

  @cust_pay = qsearch('cust_pay', { 'payinfo' => $payinfo,
                                     'payby'   => $payby    } );
  $sortby = \*date_sort;

}

if (0) {
#if ( scalar(@cust_pay) == 1 ) {
#  my $invnum = $cust_bill[0]->invnum;
#  print $cgi->redirect(popurl(2). "view/cust_bill.cgi?$invnum");  #redirect
} elsif ( scalar(@cust_pay) == 0 ) {
%>
<!-- mason kludge -->
<%
  idiot("Payment not found.");
  #exit;
} else {
  my $total = scalar(@cust_pay);
  my $s = $total > 1 ? 's' : '';
%>
<!-- mason kludge -->
<%
  print header("Payment Search Results", menubar(
          'Main Menu', popurl(2)
        )), "$total matching payment$s found<BR>", &table(), <<END;
      <TR>
        <TH></TH>
        <TH>Amount</TH>
        <TH>Date</TH>
        <TH>Contact name</TH>
        <TH>Company</TH>
      </TR>
END

  my(%saw, $cust_pay);
  foreach my $cust_pay (
    sort $sortby grep(!$saw{$_->paynum}++, @cust_pay)
  ) {
    my($paynum, $custnum, $payby, $payinfo, $amount, $date ) = (
      $cust_pay->paynum,
      $cust_pay->custnum,
      $cust_pay->payby,
      $cust_pay->payinfo,
      sprintf("%.2f", $cust_pay->paid),
      $cust_pay->_date,
    );
    my $pdate = time2str("%b&nbsp;%d&nbsp;%Y", $date);

    my $rowspan = 1;

    my $view = popurl(2). "view/cust_main.cgi?". $custnum. 
               "#". $payby. $payinfo;

    my $payment_info;
    if ( $payby eq 'CARD' ) {
      $payment_info = 'Card&nbsp;#'. 'x'x(length($payinfo)-4).
                      substr($payinfo,(length($payinfo)-4));
    } elsif ( $payby eq 'CHEK' ) {
      $payment_info = "E-check&nbsp;acct#$payinfo";
    } elsif ( $payby eq 'BILL' ) {
      $payment_info = "Check&nbsp;#$payinfo";
    } else {
      $payment_info = "$payby&nbsp;$payinfo";
    }

    print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$payment_info</FONT></A></TD>
        <TD ROWSPAN=$rowspan ALIGN="right"><A HREF="$view"><FONT SIZE=-1>\$$amount</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$pdate</FONT></A></TD>
END
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
    if ( $cust_main ) {
      #my $cview = popurl(2). "view/cust_main.cgi?". $cust_main->custnum;
      my ( $name, $company ) = (
        $cust_main->last. ', '. $cust_main->first,
        $cust_main->company,
      );
      print <<END;
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$name</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$company</FONT></A></TD>
END
    } else {
      print <<END
        <TD ROWSPAN=$rowspan COLSPAN=2>WARNING: couldn't find cust_main.custnum $custnum (cust_pay.paynum $paynum)</TD>
END
    }

    print "</TR>";
  }
  print <<END;
    </TABLE>
  </BODY>
</HTML>
END

}

#

#sub invnum_sort {
#  $a->invnum <=> $b->invnum;
#}
#
#sub custnum_sort {
#  $a->custnum <=> $b->custnum || $a->invnum <=> $b->invnum;
#}

sub date_sort {
  $a->_date <=> $b->_date || $a->invnum <=> $b->invnum;
}
%>
