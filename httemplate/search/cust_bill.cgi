<%

my $conf = new FS::Conf;
my $maxrecords = $conf->config('maxsearchrecordsperpage');

my $orderby = ''; #removeme

my $limit = '';
$limit .= "LIMIT $maxrecords" if $maxrecords;

my $offset = $cgi->param('offset') || 0;
$limit .= " OFFSET $offset" if $offset;

my $total;

my(@cust_bill, $sortby);
if ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  my $open_sql =
    "having 0 != charged - coalesce(sum(cust_bill_pay.amount),0)
                         - coalesce(sum(cust_credit_bill.amount),0)";
  my $having = '';
  my $where = '';
  if ( $query eq 'invnum' ) {
    $sortby = \*invnum_sort;
    #@cust_bill = qsearch('cust_bill', {} );
  } elsif ( $query eq 'date' ) {
    $sortby = \*date_sort;
    #@cust_bill = qsearch('cust_bill', {} );
  } elsif ( $query eq 'custnum' ) {
    $sortby = \*custnum_sort;
    #@cust_bill = qsearch('cust_bill', {} );
  } elsif ( $query eq 'OPEN_invnum' ) {
    $sortby = \*invnum_sort;
    #@cust_bill = grep $_->owed != 0, qsearch('cust_bill', {} );
    $having = $open_sql;
  } elsif ( $query eq 'OPEN_date' ) {
    $sortby = \*date_sort;
    #@cust_bill = grep $_->owed != 0, qsearch('cust_bill', {} );
    $having = $open_sql;
  } elsif ( $query eq 'OPEN_custnum' ) {
    $sortby = \*custnum_sort;
    #@cust_bill = grep $_->owed != 0, qsearch('cust_bill', {} );
    $having = $open_sql;
  } elsif ( $query =~ /^OPEN(\d+)_invnum$/ ) {
    my $open = $1 * 86400;
    $sortby = \*invnum_sort;
    #@cust_bill =
    #  grep $_->owed != 0 && $_->_date < time - $open, qsearch('cust_bill', {} );
    $having = $open_sql;
    $where = "where cust_bill._date < ". (time-$open);
  } elsif ( $query =~ /^OPEN(\d+)_date$/ ) {
    my $open = $1 * 86400;
    $sortby = \*date_sort;
    #@cust_bill =
    #  grep $_->owed != 0 && $_->_date < time - $open, qsearch('cust_bill', {} );
    $having = $open_sql;
    $where = "where cust_bill._date < ". (time-$open);
  } elsif ( $query =~ /^OPEN(\d+)_custnum$/ ) {
    my $open = $1 * 86400;
    $sortby = \*custnum_sort;
    #@cust_bill =
    #  grep $_->owed != 0 && $_->_date < time - $open, qsearch('cust_bill', {} );
    $having = $open_sql;
    $where = "where cust_bill._date < ". (time-$open);
  } else {
    die "unknown query string $query";
  }

  my $extra_sql = "
    left outer join cust_bill_pay using ( invnum )
    left outer join cust_credit_bill using ( invnum )
    $where
    group by ". join(', ', map "cust_bill.$_", fields('cust_bill') ). ' '.
    $having;

  my $statement = "SELECT COUNT(*) FROM cust_bill $extra_sql";
  my $sth = dbh->prepare($statement) or die dbh->errstr. " doing $statement";
  $sth->execute or die "Error executing \"$statement\": ". $sth->errstr;

  $total = $sth->fetchrow_arrayref->[0];

  @cust_bill = qsearch(
    'cust_bill',
    {},
    'cust_bill.*,
     charged - coalesce(sum(cust_bill_pay.amount),0)
              - coalesce(sum(cust_credit_bill.amount),0) as owed',
    "$extra_sql $orderby $limit"
  );
} else {
  $cgi->param('invnum') =~ /^\s*(FS-)?(\d+)\s*$/;
  my $invnum = $2;
  @cust_bill = qsearchs('cust_bill', { 'invnum' => $invnum } );
  $sortby = \*invnum_sort;
  $total = scalar(@cust_bill);
}

#if ( scalar(@cust_bill) == 1 ) {
if ( scalar(@cust_bill) == 1 && $total == 1) {
#if ( $total == 1 ) {
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
  #$total = scalar(@cust_bill);

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
        )), "$total matching invoices found<BR><BR>$pager", &table(), <<END;
      <TR>
        <TH></TH>
        <TH>Balance</TH>
        <TH>Amount</TH>
        <TH>Date</TH>
        <TH>Contact name</TH>
        <TH>Company</TH>
      </TR>
END

  my(%saw, $cust_bill);
  my($tot_balance, $tot_amount) = (0, 0); #BOGUS
  foreach $cust_bill (
    sort $sortby grep(!$saw{$_->invnum}++, @cust_bill)
  ) {
    my($invnum, $owed, $charged, $date ) = (
      $cust_bill->invnum,
      sprintf("%.2f", $cust_bill->owed),
      sprintf("%.2f", $cust_bill->charged),
      $cust_bill->_date,
    );
    my $pdate = time2str("%b %d %Y", $date);

    $tot_balance += $owed;
    $tot_amount += $charged;

    my $rowspan = 1;

    my $view = popurl(2). "view/cust_bill.cgi?$invnum";
    print <<END;
      <TR>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$invnum</FONT></A></TD>
        <TD ROWSPAN=$rowspan ALIGN="right"><A HREF="$view"><FONT SIZE=-1>\$$owed</FONT></A></TD>
        <TD ROWSPAN=$rowspan ALIGN="right"><A HREF="$view"><FONT SIZE=-1>\$$charged</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$view"><FONT SIZE=-1>$pdate</FONT></A></TD>
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
        <TD ROWSPAN=$rowspan><A HREF="$cview"><FONT SIZE=-1>$name</FONT></A></TD>
        <TD ROWSPAN=$rowspan><A HREF="$cview"><FONT SIZE=-1>$company</FONT></A></TD>
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
  print <<END;
      <TR><TD></TD><TH><FONT SIZE=-1>Total</FONT></TH><TH><FONT SIZE=-1>Total</FONT></TH></TR>
      <TR><TD></TD><TD ALIGN="right"><FONT SIZE=-1>\$$tot_balance</FONT></TD><TD ALIGN="right"><FONT SIZE=-1>\$$tot_amount</FONT></TD></TD></TR>
    </TABLE>$pager
  </BODY>
</HTML>
END

}

#

sub invnum_sort {
  $a->invnum <=> $b->invnum;
}

sub custnum_sort {
  $a->custnum <=> $b->custnum || $a->invnum <=> $b->invnum;
}

sub date_sort {
  $a->_date <=> $b->_date || $a->invnum <=> $b->invnum;
}
%>
