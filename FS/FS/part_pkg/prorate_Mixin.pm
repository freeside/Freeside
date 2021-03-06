package FS::part_pkg::prorate_Mixin;

use strict;
use vars qw( %info );
use Tie::IxHash;
use Time::Local qw( timelocal timelocal_nocheck );
use Date::Format qw( time2str );
use List::Util qw( min );

tie our %prorate_round_day_opts, 'Tie::IxHash',
  0   => 'no',
  1   => 'to the nearest day',
  2   => 'up to a full day',
  3   => 'down to a full day',
;

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
                'name' => 'When prorating, round the prorated period',
                'type' => 'select',
                'select_options' => \%prorate_round_day_opts,
    },
    'prorate_defer_bill' => {
                'name' => 'When prorating, defer the first bill until the '.
                          'billing day or customers next bill date if synchronizing.',
                'type' => 'checkbox',
    },
    'prorate_verbose' => {
                'name' => 'Show prorate details on the invoice',
                'type' => 'checkbox',
    },
  },
  'fieldorder' => [ qw(prorate_defer_bill prorate_round_day 
                       add_full_period prorate_verbose) ],
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
- prorate_verbose: Generate details to explain the prorate calculations.

=cut

sub calc_prorate {
  my ($self, $cust_pkg, $sdate, $details, $param, @cutoff_days) = @_;
  die "no cutoff_day" unless @cutoff_days;
  die "can't prorate non-monthly package\n" if $self->freq =~ /\D/;

  my $money_char = FS::Conf->new->config('money_char') || '$';

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
    $param->{'setup_fee'} = $self->calc_setup($cust_pkg, $$sdate, $details)
      unless $cust_pkg->{'Hash'}->{'waive_setup'};
    $mnow = $cust_pkg->setup;
    $add_period = 1;
  }

  # if the customer already has a billing day-of-month established,
  # and it's a valid cutoff day, try to respect it
  my $next_bill_day;
  if ( my $next_bill = $cust_pkg->cust_main->next_bill_date ) {
    $next_bill_day = (localtime($next_bill))[3];
    if ( grep {$_ == $next_bill_day} @cutoff_days ) {
      # by removing all other cutoff days from the list
      @cutoff_days = ($next_bill_day);
    }
  }

  my ($mend, $mstart);
  ($mnow, $mend, $mstart) = $self->_endpoints($mnow, @cutoff_days);

  # next bill date will be figured as $$sdate + one period
  $$sdate = $mstart;

  my $permonth = $charge / $self->freq;
  my $months = ( ( $self->freq - 1 ) + ($mend-$mnow) / ($mend-$mstart) );
  # after this, $self->freq - 1 < $months <= $self->freq

  # add a full period if currently billing for a partial period
  # or periods up to freq_override if billing for an override interval
  if ( ($param->{'freq_override'} || 0) > 1 ) {
    $months += $param->{'freq_override'} - 1;
    # freq_override - 1 correct here?
    # (probably only if freq == 1, yes?)
  } elsif ( $add_period && $months < $self->freq ) {

    # 'add_period' is a misnomer.
    # we add enough to make the total at least a full period
    $months++;
    $$sdate = $self->add_freq($mstart, 1);
    # now $self->freq <= $months <= $self->freq + 1
    # (note that this only happens if $months < $self->freq to begin with)

  }

  if ( $self->option('prorate_verbose',1) and $months > 0 ) {
    if ( $months < $self->freq ) {
      # we are billing a fractional period only
      #       # (though maybe not a fractional month)
      my $period_end = $self->add_freq($mstart);
      push @$details, 
      'Prorated (' . time2str('%b %d', $mnow) .
      ' - ' . time2str('%b %d', $period_end) . '): ' . $money_char .
      sprintf('%.2f', $permonth * $months + 0.00000001 );

    } elsif ( $months > $self->freq ) {
      # we are billing MORE than a full period
      push @$details,

      'Prorated (' . time2str('%b %d', $mnow) .
      ' - ' . time2str('%b %d', $mend) . '): ' . $money_char .
      sprintf('%.2f', $permonth * ($months - $self->freq + 0.0000001)),

      'First full period: ' . $money_char .
      sprintf('%.2f', $permonth * $self->freq);
    } # else $months == $self->freq, and no prorating has happened
  }

  $param->{'months'} = $months;
                                                  #so 1.005 rounds to 1.01
  $charge = sprintf('%.2f', $permonth * $months + 0.00000001 );

  return sprintf('%.2f', $charge);
}

=item prorate_setup CUST_PKG SDATE

Set up the package.  This only has an effect if prorate_defer_bill is 
set, in which case it postpones the next bill to the cutoff day.

=cut

sub prorate_setup {
  my ($self, $cust_pkg, $time) = @_;
  my @cutoff_days = $self->cutoff_day($cust_pkg);
  if ( @cutoff_days and $self->option('prorate_defer_bill', 1) ) {
    if ( $cust_pkg->setup ) {
      # Setup date is already set. Then we're being called indirectly via calc_prorate
      # to calculate the deferred setup fee. Allow that to happen normally.
      return 0;
    } else {
      # We're going to set the setup date (so that the deferred billing knows when
      # the package started) and suppress charging the setup fee.
      if ( $cust_pkg->bill ) {
        # For some reason (probably user override), the bill date has been set even
        # though the package isn't billing yet. Start billing as though that was the
        # start date.
        $time = $cust_pkg->bill;
        $cust_pkg->setup($cust_pkg->bill);
      }
      # Now figure the start and end of the period that contains the start date.
      my ($mnow, $mend, $mstart) = $self->_endpoints($time, @cutoff_days);
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
  my $self = shift;
  my $mnow = shift;
  my @cutoff_days = sort {$a <=> $b} @_;

  # only works for freq >= 1 month; probably can't be fixed
  my ($sec, $min, $hour, $mday, $mon, $year) = (localtime($mnow))[0..5];
  my $rounding_mode = $self->option('prorate_round_day',1);
  if ( $rounding_mode == 1 ) {
    # If the time is 12:00-23:59, move to the next day by adding 18 
    # hours to $mnow.  Because of DST this can end up from 05:00 to 18:59
    # but it's always within the next day.
    $mnow += 64800 if $hour >= 12;
    # Get the new day, month, and year.
    ($mday,$mon,$year) = (localtime($mnow))[3..5];
    # Then set $mnow to midnight on that day.
    $mnow = timelocal(0,0,0,$mday,$mon,$year);
  } elsif ( $rounding_mode == 2 ) {
    # Move the time back to midnight. This increases the length of the
    # prorate interval.
    $mnow = timelocal(0,0,0,$mday,$mon,$year);
    ($mday,$mon,$year) = (localtime($mnow))[3..5];
  } elsif ( $rounding_mode == 3 ) {
    # If the time is after midnight, move it forward to the next midnight.
    # This decreases the length of the prorate interval.
    if ( $sec > 0 or $min > 0 or $hour > 0 ) {
      # move to one second before midnight, then tick forward
      $mnow = timelocal(59,59,23,$mday,$mon,$year) + 1;
      ($mday,$mon,$year) = (localtime($mnow))[3..5];
    }
  }
  my $mend;
  my $mstart;
  # select the first cutoff day that's on or after the current day
  my $cutoff_day = min( grep { $_ >= $mday } @cutoff_days );
  # if today is after the last cutoff, choose the first one
  $cutoff_day ||= $cutoff_days[0];

  # then, if today is on or after the selected day, set period to
  # (cutoff day this month) - (cutoff day next month)
  if ( $mday >= $cutoff_day ) {
    $mend = 
      timelocal_nocheck(0,0,0,$cutoff_day,$mon == 11 ? 0 : $mon + 1,$year+($mon==11));
    $mstart =
      timelocal_nocheck(0,0,0,$cutoff_day,$mon,$year);
  }
  # otherwise, set period to (cutoff day last month) - (cutoff day this month)
  else {
    $mend = 
      timelocal_nocheck(0,0,0,$cutoff_day,$mon,$year);
    $mstart = 
      timelocal_nocheck(0,0,0,$cutoff_day,$mon == 0 ? 11 : $mon - 1,$year-($mon==0));
  }
  return ($mnow, $mend, $mstart);
}

1;
