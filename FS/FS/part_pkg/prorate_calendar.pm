package FS::part_pkg::prorate_calendar;

use strict;
use vars qw(@ISA %info);
use DateTime;
use Tie::IxHash;
use base 'FS::part_pkg::flat';

# weird stuff in here

%info = (
  'name' => 'Prorate to specific calendar day(s), then flat-rate',
  'shortname' => 'Prorate (calendar cycle)',
  'inherit_fields' => [ 'flat', 'usage_Mixin', 'global_Mixin' ],
  'fields' => {
    'recur_temporality' => {'disabled' => 1},
    'sync_bill_date' => {'disabled' => 1},# god help us all

    'cutoff_day' => { 'name' => 'Billing day (1 - end of cycle)',
                      'default' => 1,
                    },

    # add_full_period is not allowed

    # prorate_round_day is always on
    'prorate_round_day' => { 'disabled' => 1 },
 
    'prorate_defer_bill'=> {
                        'name' => 'Defer the first bill until the billing day',
                        'type' => 'checkbox',
                        },
    'prorate_verbose' => {
                        'name' => 'Show prorate details on the invoice',
                        'type' => 'checkbox',
                        },
  },
  'fieldorder' => [ 'cutoff_day', 'prorate_defer_bill', 'prorate_round_day', 'prorate_verbose' ],
  'freq' => 'm',
  'weight' => 20,
);

my %freq_max_days = ( # the length of the shortest period of each cycle type
  '1'   => 28,
  '2'   => 59,   # Jan - Feb
  '3'   => 90,   # Jan - Mar
  '4'   => 120,  # Jan - Apr
  '6'   => 181,  # Jan - Jun
  '12'  => 365,
);

my %freq_cutoff_days = (
  '1'   => [ 31, 28, 31, 30, 31, 30,
             31, 31, 30, 31, 30, 31 ],
  '2'   => [ 59, 61, 61, 62, 61, 61 ],
  '3'   => [ 90, 91, 92, 92 ],
  '4'   => [ 120, 123, 122 ],
  '6'   => [ 181, 184 ],
  '12'  => [ 365 ],
);

sub check {
  # yes, this package plan is such a special snowflake it needs its own
  # check method.
  my $self = shift;

  if ( !exists($freq_max_days{$self->freq}) ) {
    return 'Prorate (calendar cycle) billing interval must be an integer factor of one year';
  }
  $self->SUPER::check;
}

sub cutoff_day {
  my( $self, $cust_pkg ) = @_;
  my @periods = @{ $freq_cutoff_days{$self->freq} };
  my @cutoffs = ($self->option('cutoff_day') || 1); # Jan 1 = 1
  pop @periods; # we don't care about the last one
  foreach (@periods) {
    push @cutoffs, $cutoffs[-1] + $_;
  }
  @cutoffs;
}

sub calc_prorate {
  # it's not the same algorithm
  my ($self, $cust_pkg, $sdate, $details, $param, @cutoff_days) = @_;
  die "no cutoff_day" unless @cutoff_days;
  die "prepaid terms not supported with calendar prorate packages"
    if $param->{freq_override}; # XXX if we ever use this again

  #XXX should we still be doing this with multi-currency support?
  my $money_char = FS::Conf->new->config('money_char') || '$';

  my $charge = $self->base_recur($cust_pkg, $sdate) || 0;
  my $now = DateTime->from_epoch(epoch => $$sdate, time_zone => 'local');

  my $add_period = 0;
  # if this is the first bill but the bill date has been set
  # (by prorate_defer_bill), calculate from the setup date,
  # append the setup fee to @$details, and make sure to bill for 
  # a full period after the bill date.

  if ( $self->option('prorate_defer_bill', 1)
    and !$cust_pkg->getfield('last_bill')
    and $cust_pkg->setup )
  {
    $param->{'setup_fee'} = $self->calc_setup($cust_pkg, $$sdate, $details);
    $now = DateTime->from_epoch(epoch => $cust_pkg->setup, time_zone => 'local');
    $add_period = 1;
  }

  # DON'T sync to the existing billing day; cutoff days work differently here.

  $now->truncate(to => 'day');
  my ($end, $start) = $self->calendar_endpoints($now, @cutoff_days);

  #warn "[prorate_calendar] now = ".$now->ymd.", start = ".$start->ymd.", end = ".$end->ymd."\n";

  my $periods = $end->delta_days($now)->delta_days /
                $end->delta_days($start)->delta_days;
  if ( $periods < 1 and $add_period ) {
    $periods++; # charge for the extra time
    $start->add(months => $self->freq); # and push the next bill date forward
  }
  if ( $self->option('prorate_verbose',1) and $periods > 0 ) {
    if ( $periods < 1 ) {
      push @$details,
        'Prorated (' . $now->strftime('%b %d') .
        ' - ' . $end->strftime('%b %d') . '): ' . $money_char .
        sprintf('%.2f', $charge * $periods + 0.00000001);
    } elsif ( $periods > 1 ) {
      push @$details,
        'Prorated (' . $now->strftime('%b %d') .
        ' - ' . $end->strftime('%b %d') . '): ' . $money_char .
        sprintf('%.2f', $charge * ($periods - 1) + 0.00000001),

        'First full period: ' . $money_char . sprintf('%.2f', $charge);
    } # else exactly one period
  }

  $$sdate = $start->epoch;
  return sprintf('%.2f', $charge * $periods + 0.00000001);
}

sub prorate_setup {
  my $self = shift;
  my ($cust_pkg, $sdate) = @_;
  my @cutoff_days = $self->cutoff_day;
  if ( ! $cust_pkg->bill
     and $self->option('prorate_defer_bill')
     and @cutoff_days )
  {
    my $now = DateTime->from_epoch(epoch => $sdate, time_zone => 'local');
    $now->truncate(to => 'day');
    my ($end, $start) = $self->calendar_endpoints($now, @cutoff_days);
    if ( $now->compare($start) == 0 ) {
      $cust_pkg->setup($start->epoch);
      $cust_pkg->bill($start->epoch);
    } else {
      $cust_pkg->bill($end->epoch);
    }
    return 1;
  } else {
    return 0;
  }
}

=item calendar_endpoints NOW CUTOFF_DAYS

Given a current date (DateTime object) and a list of cutoff day-of-year
numbers, finds the next upcoming cutoff day (in either the current or the 
upcoming year) and the cutoff day before that, and returns them both.

=cut

sub calendar_endpoints {
  my $self = shift;
  my $now = shift;
  my @cutoff_day = sort {$a <=> $b} @_;

  my $year = $now->year;
  my $day = $now->day_of_year;
  # Feb 29 = 60 
  # For cutoff day purposes, it's the same day as Feb 28
  $day-- if $now->is_leap_year and $day >= 60;

  # select the first cutoff day that's after the current day
  my $i = 0;
  while ( $cutoff_day[$i] and $cutoff_day[$i] <= $day ) {
    $i++;
  }
  # $cutoff_day[$i] is now later in the calendar than today
  # or today is between the last cutoff day and the end of the year

  my ($start, $end);
  if ( $i == 0 ) {
    # then today is on or before the first cutoff day
    $start = DateTime->from_day_of_year(year => $year - 1,
                                        day_of_year => $cutoff_day[-1],
                                        time_zone => 'local');
    $end =   DateTime->from_day_of_year(year => $year,
                                        day_of_year => $cutoff_day[0],
                                        time_zone => 'local');
  } elsif ( $i > 0 and $i < scalar(@cutoff_day) ) {
    # today is between two cutoff days
    $start = DateTime->from_day_of_year(year => $year,
                                        day_of_year => $cutoff_day[$i - 1],
                                        time_zone => 'local');
    $end =   DateTime->from_day_of_year(year => $year,
                                        day_of_year => $cutoff_day[$i],
                                        time_zone => 'local');
  } else {
    # today is after the last cutoff day
    $start = DateTime->from_day_of_year(year => $year,
                                        day_of_year => $cutoff_day[-1],
                                        time_zone => 'local');
    $end =   DateTime->from_day_of_year(year => $year + 1,
                                        day_of_year => $cutoff_day[0],
                                        time_zone => 'local');
  }
  return ($end, $start);
}

1;
