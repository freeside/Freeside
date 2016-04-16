
<% include('/graph/elements/report.html',
     'title'      => 'Monthly Sales and Taxes Report',
     'items'      => \@row_labels,
     'data'       => \@rowdata,
     'row_labels' => \@row_labels,
     'colors'     => \@rowcolors,
     'bgcolors'   => \@rowbgcolors,
     'col_labels' => \@col_labels,
     'graph_type' => 'none',
   ) %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports');

# validate cgi input
my $start_month = $cgi->param('start_month');
die "Bad start month" unless $start_month =~ /^\d*$/;
my $start_year = $cgi->param('start_year');
die "Bad start year" unless $start_year =~ /^\d*$/;
my $end_month = $cgi->param('end_month');
die "Bad end month" unless $end_month =~ /^\d*$/;
my $end_year = $cgi->param('end_year');
die "Bad end year" unless $end_year =~ /^\d*$/;
die "End year before start year" if $end_year < $start_year;
die "End month before start month" if ($start_year == $end_year) && ($end_month < $start_month);
my $country = $cgi->param('country');
die "Bad country code" unless $country =~ /^\w\w$/;

# Data structure for building final table
# row order will be calculated separately
#
# $data->{$rowlabel} = \@rowvalues
#

my $data = {};

### Calculate package values

my @pkg_class = qsearch('pkg_class');
my @pkg_classnum = map { $_->classnum } @pkg_class;
unshift(@pkg_classnum,0);
my @pkg_classname = map { $_->classname } @pkg_class;
unshift(@pkg_classname,'(empty class)');

# some false laziness with graph/elements/monthly.html
my %reportopts = (
  'items'        => [ qw( cust_bill_pkg cust_bill_pkg_credits ) ],
  'cross_params' => [ map { [ 'classnum', $_ ] } @pkg_classnum ],
  'start_month'  => $start_month,
  'start_year'   => $start_year,
  'end_month'    => $end_month,
  'end_year'     => $end_year,
);
my $pkgreport = new FS::Report::Table::Monthly(%reportopts);
my $pkgdata = $pkgreport->data;

# assuming every month/year combo is included in results,
# just use this list for the final table
my @col_labels = @{$pkgdata->{'label'}}; 

# unpack report data into a more manageable format
foreach my $item ( qw( invoiced credited ) ) { # invoiced, credited
  my $itemref = shift @{$pkgdata->{'data'}};
  foreach my $label (@{$pkgdata->{'label'}}) { # month/year
    my $labelref = shift @$itemref;
    foreach my $classname (@pkg_classname) {   # pkg class
      my $value = shift @$labelref;
      my $rowlabel = $classname.' '.$item;
      $data->{$rowlabel} ||= [];
      push(@{$data->{$rowlabel}},$value);
    }
  }
}

### Calculate tax values

# false laziness w report_tax.html, put this in FS::Report::Tax?
my $sth = dbh->prepare('SELECT DISTINCT(COALESCE(taxname, \'Tax\')) FROM cust_main_county');
$sth->execute or die $sth->errstr;
my @taxnames = map { $_->[0] } @{ $sth->fetchall_arrayref };
$sth->finish;

# get DateTime objects for start & end
my $startdate = DateTime->new(
                  year => $start_year,
                  month => $start_month,
                  day => 1
                );
my $enddate   = DateTime->new(
                  year => $end_year,
                  month => $end_month,
                  day => 1
                );
$enddate->add( months => 1 )->subtract( seconds => 1 ); # the last second of the month

# common to all tax reports
my %params = ( 
  'country' => $country,
  'credit_date' => 'cust_bill',
);

# run a report for each month, for each tax
my $countdate = $startdate->clone;
while ($countdate < $enddate) {

  # set report start date, iterate to end of this month, set report end date
  $params{'beginning'} = $countdate->epoch;
  $params{'ending'} = $countdate->add( months => 1 )->subtract( seconds => 1 )->epoch;

  # run a report for each tax name
  foreach my $taxname (@taxnames) {
    $params{'taxname'} = $taxname;
    my $report = FS::Report::Tax::ByName->report(%params);

    # extract totals from report, kinda awkward
    my $pkgclass = ''; # this will get more complicated if we breakdown by pkgclass
    my @values = (0,0);
    if ($report->{'total'}->{$pkgclass}) {
      my %totals = map { $$_[0] => $$_[2] } @{$report->{'total'}->{$pkgclass}};
      $values[0] = $totals{'tax'};
      $values[1] = $totals{'credit'};
    }

    # treat each tax class like it's an additional pkg class
    foreach my $item ( qw ( invoiced credited ) ) {
      my $rowlabel = $taxname . ' ' . $item;
      my $value = shift @values;
      $data->{$rowlabel} ||= [];
      push(@{$data->{$rowlabel}},$value);
    }

  }

  # iterate to next month
  $countdate->add( seconds => 1 );
}

# put the data in the order we want it
my @row_labels;
my @rowdata;
my @rowcolors;
my @rowbgcolors;
my $pkgcount = 0; #for colors
foreach my $classname (@pkg_classname,@taxnames) {
  my $istax = ($pkgcount++ < @pkg_classname) ? 0 : 1;
  my @classlabels = ();
  my @classdata = ();
  my @classcolors = ();
  my @classbgcolors = ();
  my $hasdata = 0;
  foreach my $item ( qw( invoiced credited ) ) {
    my $rowlabel = $classname . ' ' . $item;
    my $rowdata  = $data->{$rowlabel};
    my $rowcolor = $istax ? '0000ff' : '000000';
    my $rowbgcolor  = ($item eq 'credited') ? 'cccccc' : 'ffffff';
    $hasdata = 1 if grep { $_ } @$rowdata;
    push(@classlabels,$rowlabel);
    push(@classdata,$rowdata);
    push(@classcolors,$rowcolor);
    push(@classbgcolors,$rowbgcolor);
  }
  next unless $hasdata; # don't include class if it has no data in time range
  push(@row_labels,@classlabels);
  push(@rowdata,@classdata);
  push(@rowcolors,@classcolors);
  push(@rowbgcolors,@classbgcolors);
}

</%init>
