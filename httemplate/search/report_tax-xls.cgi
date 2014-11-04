<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

my $DEBUG = $cgi->param('debug') || 0;

my $conf = new FS::Conf;

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

my %params = (
  beginning => $beginning,
  ending    => $ending,
);
$params{country} = $cgi->param('country');
$params{debug}   = $DEBUG;
$params{breakdown} = { map { $_ => 1 } $cgi->param('breakdown') };

my $agentname;
if ( $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  my $agent = FS::agent->by_key($1) or die "unknown agentnum $1";
  $params{agentnum} = $1;
  $agentname = $agent->agentname;
}

if ( $cgi->param('taxname') =~ /^([\w ]+)$/ ) {
  $params{taxname} = $1;
} else {
  die "taxname required";
}

# generate the report
my $report = FS::Report::Tax->report_internal(%params);
my @rows = $report->table; # array of hashrefs

my %pkgclass_name = map { $_->classnum, $_->classname } qsearch('pkg_class');
$pkgclass_name{''} = 'Unclassified';

my $override = (scalar(@rows) >= 65536 ? 'XLSX' : '');
my $format = $FS::CurrentUser::CurrentUser->spreadsheet_format($override);
my $filename = 'report_tax'.$format->{extension};

http_header('Content-Type' => $format->{mime_type});
http_header('Content-Disposition' => qq!attachment;filename="$filename"! );

my $data = '';
my $XLS = new IO::Scalar \$data;
my $workbook = $format->{class}->new($XLS)
  or die "Error opening .xls file: $!";

# hardcoded formats, this could be handled better
my $light_gray = $workbook->set_custom_color(63, '#eeeeee');
my %formatdef = (
  title => {
    size      => 24,
    align     => 'center',
    bg_color  => 'silver',
  },
  sectionhead => {
    size      => 11,
    bold      => 1,
    bg_color  => 'silver',
  },
  colhead => {
    size      => 11,
    bold      => 1,
    align     => 'center',
    valign    => 'vcenter',
    text_wrap => 1,
  },
  colhead_small => {
    size      => 8,
    bold      => 1,
    align     => 'center',
    valign    => 'vcenter',
    text_wrap => 1,
  },
  rowhead => {
    size      => 11,
    valign    => 'bottom',
    text_wrap => 1,
  },
  currency => {
    size      => 11,
    align     => 'right',
    valign    => 'bottom',
    num_format=> 8, # ($#,##0.00_);[Red]($#,##0.00)
  },
  number  => {
    size      => 11,
    align     => 'right',
    valign    => 'bottom',
    num_format=> 10, # 0.00%
  },
  bigmath => {
    size      => 12,
    align     => 'center',
    valign    => 'vcenter',
    bold      => 1,
  },
  rowhead_outside => {
    size      => 11,
    align     => 'left',
    valign    => 'vcenter',
    bg_color  => 'gray',
    bold      => 1,
    italic    => 1,
  },
  currency_outside => {
    size      => 11,
    align     => 'right',
    valign    => 'vcenter',
    bg_color  => 'gray',
    italic    => 1,
    num_format=> 8, # ($#,##0.00_);[Red]($#,##0.00)
  },

);
my %default = (
  font      => 'Calibri',
  border    => 1,
);
my @widths = ( #ick
  30, (13) x 5, 3, 7.5, 3, 11, 11, 3, 11, 3, 11
);

my @format = ( {}, {}, {} ); # white row, gray row, yellow (totals) row
foreach (keys(%formatdef)) {
  my %f = (%default, %{$formatdef{$_}});
  $format[0]->{$_} = $workbook->add_format(%f);
  $format[1]->{$_} = $workbook->add_format(bg_color => $light_gray, %f);
  $format[2]->{$_} = $workbook->add_format(bg_color => 'yellow',
                                           italic   => 1,
                                           %f);
}
my $ws = $workbook->add_worksheet('taxreport');

# main title
$ws->merge_range(0, 0, 0, 14, $report->title, $format[0]->{title});
# excel position
my $x = 0;
my $y = 2;

my $colhead = $format[0]->{colhead};
# print header
$ws->merge_range($y, 1, $y, 5, 'Sales', $colhead);
$ws->merge_range($y, 6, $y+1, 8, 'Rate', $colhead);
$ws->merge_range($y, 9, $y, 14, 'Tax', $colhead);

$y++;
$colhead = $format[0]->{colhead_small};
$ws->write($y, 1, [ 'Total', 'Exempt customer', 'Exempt package', 'Monthly exemption',
                    'Taxable' ], $colhead);
$ws->write($y, 9, 'Estimated', $colhead);
$ws->write($y, 10, 'Invoiced', $colhead);
$ws->write($y, 12, 'Credited', $colhead);
$ws->write($y, 14, 'Net due',  $colhead);
$y++;

# print data
my $rownum = 0;
my $prev_row = { pkgclass => 'DUMMY PKGCLASS' };

foreach my $row (@rows) {
  $x = 0;
  if ( $row->{pkgclass} ne $prev_row->{pkgclass} ) {
    $rownum = 0;
    if ( $params{breakdown}->{pkgclass} ) {
      $ws->merge_range($y, 0, $y, 14,
        $pkgclass_name{$row->{pkgclass}},
        $format[0]->{sectionhead}
      );
      $y++;
    }
  }
  # pick a format set
  my $f = $format[$rownum % 2];
  if ( $row->{total} ) {
    $f = $format[2];
  }
  $ws->write($y, $x, $row->{label}, $f->{rowhead});
  $x++;
  foreach (qw(sales exempt_cust exempt_pkg exempt_monthly taxable)) {
    $ws->write($y, $x, $row->{$_} || 0, $f->{currency});
    $x++;
  }
  $ws->write_string($y, $x, " \N{U+00D7} ", $f->{bigmath}); # MULTIPLICATION SIGN
  $x++;
  my $rate = $row->{rate};
  $rate = $rate / 100 if $rate =~ /^[\d\.]+$/;
  $ws->write($y, $x, $rate, $f->{number});
  $x++;
  $ws->write_string($y, $x, " = ", $f->{bigmath});
  $x++;
  my $estimated = $row->{estimated} || 0;
  $estimated = '' if $rate eq 'variable';
  $ws->write($y, $x, $estimated, $f->{currency});
  $x++;
  $ws->write($y, $x, $row->{tax} || 0, $f->{currency});
  $x++;
  $ws->write_string($y, $x, " \N{U+2212} ", $f->{bigmath}); # MINUS SIGN
  $x++;
  $ws->write($y, $x, $row->{credit} || 0, $f->{currency});
  $x++;
  $ws->write_string($y, $x, " = ", $f->{bigmath});
  $x++;
  $ws->write($y, $x, $row->{tax} - $row->{credit}, $f->{currency});

  $rownum++;
  $y++;
  $prev_row = $row;
}

# at the end of everything
if ( $report->{outside} > 0 ) {
  my $f = $format[0];
  $ws->set_row($y, 30); # height
  $ws->write($y, 0, mt('Out of taxable region'), $f->{rowhead_outside});
  $ws->write($y, 1, $report->{outside}, $f->{currency_outside});
  $y++;
}

# ewwwww...
for my $x (0..scalar(@widths)-1) {
  $ws->set_column($x, $x, $widths[$x]);
}

$workbook->close;

http_header('Content-Length' => length($data));
$m->print($data);
</%init>
