<%

my $conf = new FS::Conf;
my $maxrecords = $conf->config('maxsearchrecordsperpage');

my $orderby = ''; #removeme

my $limit = '';
$limit .= "LIMIT $maxrecords" if $maxrecords;

my $offset = $cgi->param('offset') || 0;
$limit .= " OFFSET $offset" if $offset;

my($total, $tot_amount, $tot_balance);

my(@cust_bill);
if ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  my $owed = "charged - ( select coalesce(sum(amount),0) from cust_bill_pay
                          where cust_bill_pay.invnum = cust_bill.invnum )
                      - ( select coalesce(sum(amount),0) from cust_credit_bill
                          where cust_credit_bill.invnum = cust_bill.invnum )";
  my @where;
  if ( $query =~ /^(OPEN(\d*)_)?(invnum|date|custnum)$/ ) {
    my($open, $days, $field) = ($1, $2, $3);
    $field = "_date" if $field eq 'date';
    $orderby = "ORDER BY cust_bill.$field";
    push @where, "0 != $owed" if $open;
    push @where, "cust_bill._date < ". (time-86400*$days) if $days;
  } else {
    die "unknown query string $query";
  }

  my $extra_sql = scalar(@where) ? 'WHERE '. join(' AND ', @where) : '';

  my $statement = "SELECT COUNT(*), sum(charged), sum($owed)
                   FROM cust_bill $extra_sql";
  my $sth = dbh->prepare($statement) or die dbh->errstr. " doing $statement";
  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;

  ( $total, $tot_amount, $tot_balance ) = @{$sth->fetchrow_arrayref};

  @cust_bill = qsearch(
    'cust_bill',
    {},
    "cust_bill.*, $owed as owed",
    "$extra_sql $orderby $limit"
  );
} else {
  $cgi->param('invnum') =~ /^\s*(FS-)?(\d+)\s*$/;
  my $invnum = $2;
  @cust_bill = qsearchs('cust_bill', { 'invnum' => $invnum } );
  $total = scalar(@cust_bill);
}

#if ( scalar(@cust_bill) == 1 ) {
if ( $total == 1 ) {
  my $invnum = $cust_bill[0]->invnum;
  print $cgi->redirect(popurl(2). "view/cust_bill.cgi?$invnum");  #redirect
} elsif ( scalar(@cust_bill) == 0 ) {
%>
<!-- mason kludge -->
<%
  eidiot("Invoice not found.");
} else {
%>
<!-- mason kludge -->
<%

  #begin pager
  my $pager = '';
  if ( $total != scalar(@cust_bill) && $maxrecords ) {
    unless ( $offset == 0 ) {
      $cgi->param('offset', $offset - $maxrecords);
      $pager .= '<A HREF="'. $cgi->self_url.
                '"><B><FONT SIZE="+1">Previous</FONT></B></A> ';
    }
    my $poff;
    my $page;
    for ( $poff = 0; $poff < $total; $poff += $maxrecords ) {
      $page++;
      if ( $offset == $poff ) {
        $pager .= qq!<FONT SIZE="+2">$page</FONT> !;
      } else {
        $cgi->param('offset', $poff);
        $pager .= qq!<A HREF="!. $cgi->self_url. qq!">$page</A> !;
      }
    }
    unless ( $offset + $maxrecords > $total ) {
      $cgi->param('offset', $offset + $maxrecords);
      $pager .= '<A HREF="'. $cgi->self_url.
                '"><B><FONT SIZE="+1">Next</FONT></B></A> ';
    }
  }
  #end pager

  print header("Invoice Search Results", menubar(
          'Main Menu', popurl(2)
        )).
        "$total matching invoices found<BR>".
        "\$$tot_balance total balance<BR>".
        "\$$tot_amount total amount<BR>".
        "<BR>$pager". table(). <<END;
      <TR>
        <TH></TH>
        <TH>Balance</TH>
        <TH>Amount</TH>
        <TH>Date</TH>
        <TH>Contact name</TH>
        <TH>Company</TH>
      </TR>
END

  foreach my $cust_bill ( @cust_bill ) {
    my($invnum, $owed, $charged, $date ) = (
      $cust_bill->invnum,
      sprintf("%.2f", $cust_bill->getfield('owed')),
      sprintf("%.2f", $cust_bill->charged),
      $cust_bill->_date,
    );
    my $pdate = time2str("%b %d %Y", $date);

    my $rowspan = 1;

    my $view = popurl(2). "view/cust_bill.cgi?$invnum";
    print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="$view">$invnum</A></TD>
        <TD ROWSPAN=$rowspan ALIGN="right"><A HREF="$view">\$$owed</A></TD>
        <TD ROWSPAN=$rowspan ALIGN="right"><A HREF="$view">\$$charged</A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view">$pdate</A></TD>
END
    my $custnum = $cust_bill->custnum;
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } );
    if ( $cust_main ) {
      my $cview = popurl(2). "view/cust_main.cgi?". $cust_main->custnum;
      my ( $name, $company ) = (
        $cust_main->last. ', '. $cust_main->first,
        $cust_main->company,
      );
      print <<END;
        <TD ROWSPAN=$rowspan><A HREF="$cview">$name</A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$cview">$company</A></TD>
END
    } else {
      print <<END
        <TD ROWSPAN=$rowspan COLSPAN=2>WARNING: couldn't find cust_main.custnum $custnum (cust_bill.invnum $invnum)</TD>
END
    }

    print "</TR>";
  }
  $tot_balance = sprintf("%.2f", $tot_balance);
  $tot_amount = sprintf("%.2f", $tot_amount);
  print "</TABLE>$pager<BR>". table(). <<END;
      <TR><TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD><TH>Total<BR>Balance</TH><TH>Total<BR>Amount</TH></TR>
      <TR><TD></TD><TD ALIGN="right">\$$tot_balance</TD><TD ALIGN="right">\$$tot_amount</TD></TD></TR>
    </TABLE>
  </BODY>
</HTML>
END

}

%>
