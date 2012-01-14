package FS::part_pkg::prorate_Mixin;

use strict;
use vars qw( %info );
use Time::Local qw( timelocal );

%info = ( 
  'disabled'  => 1,
  # define all fields that are referenced in this code
  'fields' => {
    'add_full_period' => { 
                'name' => 'When prorating first month, also bill for one full '.
                          'period after that',
                'type' => 'checkbox',
    },
    'prorate_round_day' => { 
                'name' => 'When prorating, round to the nearest full day',
                'type' => 'checkbox',
    },
    'prorate_defer_bill' => {
                'name' => 'When prorating, defer the first bill until the '.
                          'billing day',
                'type' => 'checkbox',
    },
  },
  'fieldorder' => [ qw(prorate_defer_bill prorate_round_day add_full_period) ],
);

sub fieldorder {
  @{ $info{'fieldorder'} }
}

=head1 NAME

FS::part_pkg::prorate_Mixin - Mixin class for part_pkg:: classes that 
need to prorate partial months

=head1 SYNOPSIS

package FS::part_pkg::...;
use base qw( FS::part_pkg::prorate_Mixin );

sub calc_recur {
  ...
  if( conditions that trigger prorate ) {
    # sets $$sdate and $param->{'months'}, returns the prorated charge
    $charges = $self->calc_prorate($cust_pkg, $sdate, $param, $cutoff_day);
  } 
  ...
}

=head METHODS

=item calc_prorate CUST_PKG SDATE DETAILS PARAM CUTOFF_DAY

Takes all the arguments of calc_recur.  Calculates a prorated charge from 
the $sdate to the cutoff day for this package definition, and sets the $sdate 
and $param->{months} accordingly.  base_recur() will be called to determine 
the base price per billing cycle.

Options:
- add_full_period: Bill for the time up to the prorate day plus one full
billing period after that.
- prorate_round_day: Round the current time to the nearest full day, 
instead of using the exact time.
- prorate_defer_bill: Don't bill the prorate interval until the prorate 
day arrives.

=cut

sub calc_prorate {
  my ($self, $cust_pkg, $sdate, $details, $param, $cutoff_day) = @_;
  die "no cutoff_day" unless $cutoff_day;
  die "can't prorate non-monthly package\n" if $self->freq =~ /\D/;

  my $charge = $self->base_recur($cust_pkg, $sdate) || 0;

  my $add_period = $self->option('add_full_period',1);

  my $mnow = $$sdate;

  # if this is the first bill but the bill date has been set
  # (by prorate_defer_bill), calculate from the setup date,
  # append the setup fee to @$details, and make sure to bill for 
  # a full period after the bill date.
  if ( $self->option('prorate_defer_bill',1)
         && ! $cust_pkg->getfield('last_bill') 
         && $cust_pkg->setup
     )
  {
    #warn "[calc_prorate] #".$cust_pkg->pkgnum.": running deferred setup\n";
    $param->{'setup_fee'} = $self->calc_setup($cust_pkg, $$sdate, $details);
    $mnow = $cust_pkg->setup;
    $add_period = 1;
  }

  my ($mend, $mstart);
  ($mnow, $mend, $mstart) = $self->_endpoints($mnow, $cutoff_day);

  # next bill date will be figured as $$sdate + one period
  $$sdate = $mstart;

  my $permonth = $charge / $self->freq;
  my $months = ( ( $self->freq - 1 ) + ($mend-$mnow) / ($mend-$mstart) );

  # add a full period if currently billing for a partial period
  # or periods up to freq_override if billing for an override interval
  if ( ($param->{'freq_override'} || 0) > 1 ) {
    $months += $param->{'freq_override'} - 1;
  } 
  elsif ( $add_period && $months < $self->freq) {
    $months += $self->freq;
    $$sdate = $self->add_freq($mstart);
  }

  $param->{'months'} = $months;
                                                  #so 1.005 rounds to 1.01
  $charge = sprintf('%.2f', $permonth * $months + 0.00000001 );

  return $charge;
}

=item prorate_setup CUST_PKG SDATE

Set up the package.  This only has an effect if prorate_defer_bill is 
set, in which case it postpones the next bill to the cutoff day.

=cut

sub prorate_setup {
  my $self = shift;
  my ($cust_pkg, $sdate) = @_;
  my $cutoff_day = $self->cutoff_day($cust_pkg);
  if ( ! $cust_pkg->bill
      and $self->option('prorate_defer_bill',1)
      and $cutoff_day
  ) {
    my ($mnow, $mend, $mstart) = $self->_endpoints($sdate, $cutoff_day);
    # If today is the cutoff day, set the next bill and setup both to 
    # midnight today, so that the customer will be billed normally for a 
    # month starting today.
    if ( $mnow - $mstart < 86400 ) {
      $cust_pkg->setup($mstart);
      $cust_pkg->bill($mstart);
    }
    else {
      $cust_pkg->bill($mend);
    }
    return 1;
  }
  return 0;
}

=item _endpoints TIME CUTOFF_DAY

Given a current time and a day of the month to prorate to, return three 
times: the start of the prorate interval (usually the current time), the
end of the prorate interval (i.e. the cutoff date), and the time one month 
before the end of the prorate interval.

=cut

sub _endpoints {
  my ($self, $mnow, $cutoff_day) = @_;

  # only works for freq >= 1 month; probably can't be fixed
  my ($sec, $min, $hour, $mday, $mon, $year) = (localtime($mnow))[0..5];
  if( $self->option('prorate_round_day',1) ) {
    # If the time is 12:00-23:59, move to the next day by adding 18 
    # hours to $mnow.  Because of DST this can end up from 05:00 to 18:59
    # but it's always within the next day.
    $mnow += 64800 if $hour >= 12;
    # Get the new day, month, and year.
    ($mday,$mon,$year) = (localtime($mnow))[3..5];
    # Then set $mnow to midnight on that day.
    $mnow = timelocal(0,0,0,$mday,$mon,$year);
  }
  my $mend;
  my $mstart;
  # if cutoff day > 28, force it to the 1st of next month
  if ( $cutoff_day > 28 ) {
    $cutoff_day = 1;
    # and if we are currently after the 28th, roll the current day 
    # forward to that day
    if ( $mday > 28 ) {
      $mday = 1;
      #set $mnow = $mend so the amount billed will be zero
      $mnow = timelocal(0,0,0,1,$mon == 11 ? 0 : $mon + 1,$year+($mon==11));
    }
  }
  if ( $mday >= $cutoff_day ) {
    $mend = 
      timelocal(0,0,0,$cutoff_day,$mon == 11 ? 0 : $mon + 1,$year+($mon==11));
    $mstart =
      timelocal(0,0,0,$cutoff_day,$mon,$year);
  }
  else {
    $mend = 
      timelocal(0,0,0,$cutoff_day,$mon,$year);
    $mstart = 
      timelocal(0,0,0,$cutoff_day,$mon == 0 ? 11 : $mon - 1,$year-($mon==0));
  }
  return ($mnow, $mend, $mstart);
}

1;
