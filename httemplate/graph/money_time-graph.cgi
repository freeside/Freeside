<%

#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my ($curmon,$curyear) = (localtime(time))[4,5];

#find first month
my $syear = $cgi->param('syear') || 1899+$curyear;
my $smonth = $cgi->param('smonth') || $curmon+1;

#find last month
my $eyear = $cgi->param('eyear') || 1900+$curyear;
my $emonth = $cgi->param('emonth') || $curmon+1;
if ( $emonth++>12 ) { $emonth-=12; $eyear++; }

my @labels;
my %data;

while ( $syear < $eyear || ( $syear == $eyear && $smonth < $emonth ) ) {
  push @labels, "$smonth/$syear";

  my $speriod = timelocal(0,0,0,1,$smonth-1,$syear);
  if ( ++$smonth == 13 ) { $syear++; $smonth=1; }
  my $eperiod = timelocal(0,0,0,1,$smonth-1,$syear);

  my $where = "WHERE _date >= $speriod AND _date < $eperiod";

  # Invoiced
  my $charged_sql = "SELECT SUM(charged) FROM cust_bill $where";
  my $charged_sth = dbh->prepare($charged_sql) or die dbh->errstr;
  $charged_sth->execute or die $charged_sth->errstr;
  my $charged = $charged_sth->fetchrow_arrayref->[0] || 0;

  push @{$data{charged}}, $charged;

  #accounts receivable
#  my $ar_sql2 = "SELECT SUM(amount) FROM cust_credit $where";
  my $credited_sql = "SELECT SUM(cust_credit_bill.amount) FROM cust_credit_bill, cust_bill WHERE cust_bill.invnum = cust_credit_bill.invnum AND cust_bill._date >= $speriod AND cust_bill._date < $eperiod";
  my $credited_sth = dbh->prepare($credited_sql) or die dbh->errstr;
  $credited_sth->execute or die $credited_sth->errstr;
  my $credited = $credited_sth->fetchrow_arrayref->[0] || 0;

    #horrible local kludge
    my $expenses_sql = "SELECT SUM(cust_bill_pkg.setup) FROM cust_bill_pkg, cust_bill, cust_pkg, part_pkg WHERE cust_bill.invnum = cust_bill_pkg.invnum AND cust_bill._date >= $speriod AND cust_bill._date < $eperiod AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum AND cust_pkg.pkgpart = part_pkg.pkgpart AND LOWER(part_pkg.pkg) LIKE 'expense _%'";
    my $expenses_sth = dbh->prepare($expenses_sql) or die dbh->errstr;
    $expenses_sth->execute or die $expenses_sth->errstr;
    my $expenses = $expenses_sth->fetchrow_arrayref->[0] || 0;

  push @{$data{ar}}, $charged-$credited-$expenses;

  #deferred revenue
#  push @{$data{defer}}, '0';

  #cashflow
  my $paid_sql = "SELECT SUM(paid) FROM cust_pay $where";
  my $paid_sth = dbh->prepare($paid_sql) or die dbh->errstr;
  $paid_sth->execute or die $paid_sth->errstr;
  my $paid = $paid_sth->fetchrow_arrayref->[0] || 0;

  my $refunded_sql = "SELECT SUM(refund) FROM cust_refund $where";
  my $refunded_sth = dbh->prepare($refunded_sql) or die dbh->errstr;
  $refunded_sth->execute or die $refunded_sth->errstr;
  my $refunded = $refunded_sth->fetchrow_arrayref->[0] || 0;

    #horrible local kludge that doesn't even really work right
    my $expenses_sql2 = "SELECT SUM(cust_bill_pay.amount) FROM cust_bill_pay, cust_bill WHERE cust_bill_pay.invnum = cust_bill.invnum AND cust_bill_pay._date >= $speriod AND cust_bill_pay._date < $eperiod AND 0 < ( select count(*) from cust_bill_pkg, cust_pkg, part_pkg WHERE cust_bill.invnum = cust_bill_pkg.invnum AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum AND cust_pkg.pkgpart = part_pkg.pkgpart AND LOWER(part_pkg.pkg) LIKE 'expense _%' )";

#    my $expenses_sql2 = "SELECT SUM(cust_bill_pay.amount) FROM cust_bill_pay, cust_bill_pkg, cust_bill, cust_pkg, part_pkg WHERE cust_bill_pay.invnum = cust_bill.invnum AND cust_bill.invnum = cust_bill_pkg.invnum AND cust_bill_pay._date >= $speriod AND cust_bill_pay._date < $eperiod AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum AND cust_pkg.pkgpart = part_pkg.pkgpart AND LOWER(part_pkg.pkg) LIKE 'expense _%'";
    my $expenses_sth2 = dbh->prepare($expenses_sql2) or die dbh->errstr;
    $expenses_sth2->execute or die $expenses_sth2->errstr;
    my $expenses2 = $expenses_sth2->fetchrow_arrayref->[0] || 0;

  push @{$data{cash}}, $paid-$refunded-$expenses2;

}

#my $chart = Chart::LinesPoints->new(1024,480);
my $chart = Chart::LinesPoints->new(768,480);

$chart->set(
  #'min_val' => 0,
  'legend' => 'bottom',
  'legend_labels' => [ #'Invoiced (cust_bill)',
                       'Accounts receivable (invoices - applied credits)',
                       #'Deferred revenue',
                       'Actual cashflow (payments - refunds)' ],
);

my @data = ( \@labels,
             #map $data{$_}, qw( ar defer cash )
             #map $data{$_}, qw( charged ar cash )
             map $data{$_}, qw( ar cash )
           );

#my $gd = $chart->plot(\@data);
#open (IMG, ">i_r_c.png");
#print IMG $gd->png;
#close IMG;

#$chart->png("i_r_c.png", \@data);

#$chart->cgi_png(\@data);

http_header('Content-Type' => 'image/png' );
#$Response->{ContentType} = 'image/png';

$chart->_set_colors();

%><%= $chart->scalar_png(\@data) %>
