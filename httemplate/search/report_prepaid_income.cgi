<!-- mason kludge -->
<%

  #doesn't yet deal with daily/weekly packages

  #needs to be re-written in sql for efficiency

  my $now = time;

  my %prepaid;

  my @cust_bill_pkg =
    grep { $_->cust_pkg && $_->cust_pkg->part_pkg->freq !~ /^([01]|\d+[dw])$/ }
      qsearch( 'cust_bill_pkg', {
                                  'recur' => { op=>'!=', value=>0 },
                                  'edate' => { op=>'>', value=>$now },
                                }, );

  foreach my $cust_bill_pkg ( @cust_bill_pkg ) {

    #conceptual false laziness w/texas tax exempt_amount stuff in
    #FS::cust_main::bill

    my $freq = $cust_bill_pkg->cust_pkg->part_pkg->freq;
    my $per_month = sprintf("%.2f", $cust_bill_pkg->recur / $freq);

    my($mon, $year) = (localtime($cust_bill_pkg->sdate) )[4,5];
    $mon+=2; $year+=1900;

    foreach my $which_month ( 2 .. $freq ) {
      until ( $mon < 13 ) { $mon -= 12; $year++; }
      $prepaid{"$year-$mon"} += $per_month;
    }

  }

%>

<%= header('Prepaid Income Report', menubar( 'Main Menu'=>$p, ) ) %>
<%= table() %>
<%

  my $total = 0;

  my ($now_mon, $now_year) = (localtime($now))[4,5];
  $now_mon+=2; $now_year+=1900;
  until ( $now_mon < 13 ) { $now_mon -= 12; $now_year++; }

  my $subseq = 0;
  for my $year ( $now_year .. 2037 ) {
    for my $mon ( ( $subseq++ ? 1 : $now_mon ) .. 12 ) {
      if ( $prepaid{"$year-$mon"} ) {
        $total += $prepaid{"$year-$mon"};
        %> <TR><TD><%= "$year-$mon" %></TD>
               <TD><%= sprintf("%.2f", $prepaid{"$year-$mon"} ) %></TD>
           </TR>
        <%
      }
    }

  }

%>
<TR><TH>Total</TH><TD><%= sprintf("%.2f", $total) %></TD></TR>
</TABLE>
</BODY>
</HTML>
