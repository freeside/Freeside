<%

#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my ($curmon,$curyear) = (localtime(time))[4,5];

#find first month
my $syear = $cgi->param('syear') || 1899+$curyear;
my $smonth = $cgi->param('smonth') || $curmon+1;

#find last month
my $eyear = $cgi->param('eyear') || 1900+$curyear;
my $emonth = $cgi->param('emonth') || $curmon+1;
#if ( $emonth++>12 ) { $emonth-=12; $eyear++; }

#my @labels;
#my %data;

my @items = qw( invoiced netsales credits payments receipts );
my %label = (
 'invoiced' => 'Gross Sales (invoiced)', 
 'netsales' => 'Net Sales (invoiced - applied credits)',
 'credits'  => 'Credits',
 'payments' => 'Gross Receipts (payments)',
 'receipts' => 'Net Receipts/Cashflow (payments - refunds)',
);
my %color = (
  'invoiced' => [ 153, 153, 255 ], #light blue
  'netsales' => [   0,   0, 204 ], #blue
  'credits'  => [ 204,   0,   0 ], #red
  'payments' => [ 153, 204, 153 ], #light green
  'receipts' => [   0, 204,   0 ], #green
);

my $report = new FS::Report::Table::Monthly (
  'items' => \@items,
  'start_month' => $smonth,
  'start_year'  => $syear,
  'end_month'   => $emonth,
  'end_year'    => $eyear,
);
my %data = %{$report->data};

#my $chart = Chart::LinesPoints->new(1024,480);
#my $chart = Chart::LinesPoints->new(768,480);
my $chart = Chart::LinesPoints->new(976,384);

my $d = 0;
$chart->set(
  #'min_val' => 0,
  'legend' => 'bottom',
  'colors' => { ( map { 'dataset'.$d++ => $color{$_} } @items ),
                #'grey_background' => [ 211, 211, 211 ],
                'grey_background' => 'white',
                'background' => [ 0xe8, 0xe8, 0xe8 ], #grey
              },
  #'grey_background' => 'false',
  'legend_labels' => [ map { $label{$_} } @items ],
  'brush_size' => 4,
  #'pt_size' => 12,
);

my @data = map { $data{$_} } ( 'label', @items );

http_header('Content-Type' => 'image/png' );

$chart->_set_colors();

%><%= $chart->scalar_png(\@data) %>
