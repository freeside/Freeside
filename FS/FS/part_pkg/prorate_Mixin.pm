package FS::part_pkg::prorate_Mixin;

use strict;
use vars qw(@ISA %info);
use Time::Local qw(timelocal);

@ISA = qw(FS::part_pkg);
%info = ( 
  'disabled'  => 1,
);

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

=item calc_prorate CUST_PKG

Takes all the arguments of calc_recur, followed by a day of the month 
to prorate to (which must be <= 28).  Calculates a prorated charge from 
the $sdate to that day, and sets the $sdate and $param->{months} accordingly.

Options:
- recur_fee: The charge to use for a complete billing period.
- add_full_period: Bill for the time up to the prorate day plus one full
billing period after that.
- prorate_round_day: Round the current time to the nearest full day, 
instead of using the exact time.

=cut

sub calc_prorate {
  my $self  = shift;
  my ($cust_pkg, $sdate, $details, $param, $cutoff_day) = @_;
 
  my $charge = $self->option('recur_fee',1) || 0;
  if($cutoff_day) {
    # only works for freq >= 1 month; probably can't be fixed
    my $mnow = $$sdate;
    my ($sec, $min, $hour, $mday, $mon, $year) = (localtime($mnow))[0..5];
    if( $self->option('prorate_round_day',1) ) {
      $mday++ if $hour >= 12;
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
        timelocal(0,0,0,$cutoff_day,$mon == 0 ? 11 : $mon - 1,$year-($mon==11));
    }
   
    # next bill date will be figured as $$sdate + one period
    $$sdate = $mstart;

    my $permonth = $charge / $self->freq;
    my $months = ( ( $self->freq - 1 ) + ($mend-$mnow) / ($mend-$mstart) );

    if ( $self->option('add_full_period',1) ) {
      # charge a full period in addition to the partial month
      $months += $self->freq;
      $$sdate = $self->add_freq($mstart);
    }

    $param->{'months'} = $months;
    $charge = sprintf('%.2f', $permonth * $months);
  }
  return $charge;
}

1;
