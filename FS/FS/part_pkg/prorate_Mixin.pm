package FS::part_pkg::prorate_Mixin;

use strict;
use vars qw(@ISA %info);
use Time::Local qw(timelocal);

@ISA = qw(FS::part_pkg);
%info = ( 'disabled' => 1 );

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

=item calc_prorate

Takes all the arguments of calc_recur, and calculates a prorated charge 
in one of two ways:

- If 'sync_bill_date' is set: Charge for a number of days to synchronize 
  this package to the customer's next bill date.  If this is their only 
  package (or they're already synchronized), that will take them through 
  one billing cycle.
- If 'cutoff_day' is set: Prorate this package so that its next bill date 
  falls on that day of the month.

=cut

sub calc_prorate {
  my $self  = shift;
  my ($cust_pkg, $sdate, $details, $param) = @_;
 
  my $charge = $self->option('recur_fee') || 0;
  my $cutoff_day;
  if( $self->option('sync_bill_date') ) {
    my $next_bill = $cust_pkg->cust_main->next_bill_date;
    if( defined($next_bill) and $next_bill != $$sdate ) {
      $cutoff_day = (localtime($next_bill))[3];
    }
    else {
      # don't prorate, assume a full month
      $param->{'months'} = $self->freq;
    }
  }
  else { # no sync, use cutoff_day or day 1
    $cutoff_day = $self->option('cutoff_day') || 1;
  }

  if($cutoff_day) {
    # only works for freq >= 1 month; probably can't be fixed
    my $mnow = $$sdate;
    my ($sec, $min, $hour, $mday, $mon, $year) = (localtime($mnow))[0..5];
    my $mend;
    my $mstart;
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
    
    $$sdate = $mstart;

    my $permonth = $self->option('recur_fee', 1) / $self->freq;
    my $months = ( ( $self->freq - 1 ) + ($mend-$mnow) / ($mend-$mstart) );
    
    $param->{'months'} = $months;
    $charge = sprintf('%.2f', $permonth * $months);
  }
  my $discount =  $self->calc_discount(@_);
  return ($charge - $discount);
}

1;
