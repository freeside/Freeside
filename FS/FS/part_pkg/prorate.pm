package FS::part_pkg::prorate;
use base qw( FS::part_pkg::flat );

use strict;
use vars qw(%info);
use Time::Local qw(timelocal);
#use FS::Record qw(qsearch qsearchs);

%info = (
  'name' => 'First partial month pro-rated, then flat-rate (selectable billing day)',
  'shortname' => 'Prorate (Nth of month billing)',
  'inherit_fields' => [ 'flat', 'usage_Mixin', 'global_Mixin' ],
  'fields' => {
    'recur_temporality' => {'disabled' => 1},
    'sync_bill_date' => {'disabled' => 1},
    'cutoff_day' => { 'name' => 'Billing Day (1 - 28)',
                      'default' => 1,
                    },

    'add_full_period'=> { 'name' => 'When prorating first month, also bill '.
                                    'for one full period after that',
                          'type' => 'checkbox',
                        },
    'prorate_round_day'=> {
                          'name' => 'Round the prorated period to the nearest '.
                                    'full day',
                          'type' => 'checkbox',
                        },
    'prorate_defer_bill'=> {
                        'name' => 'Defer the first bill until the billing day',
                        'type' => 'checkbox',
                        },
    'prorate_verbose' => {
                        'name' => 'Show prorate details on the invoice',
                        'type' => 'checkbox',
                        },
  },
  'fieldorder' => [ 'cutoff_day', 'prorate_defer_bill', 'add_full_period', 'prorate_round_day', 'prorate_verbose' ],
  'freq' => 'm',
  'weight' => 20,
);

sub calc_recur {
  my $self = shift;
  #my($cust_pkg, $sdate, $details, $param ) = @_;
  my $cust_pkg = $_[0];

  my $charge = $self->calc_prorate(@_, $self->cutoff_day($cust_pkg));

  $charge += $self->usageprice_recur(@_);
  $cust_pkg->apply_usageprice(); #$sdate for prorating?

  my $discount = $self->calc_discount(@_);

  sprintf( '%.2f', ($cust_pkg->quantity || 1) * ($charge - $discount) );

}

sub cutoff_day {
  my( $self, $cust_pkg ) = @_;
  my $prorate_day = $cust_pkg->cust_main->prorate_day;
  $prorate_day ? ( $prorate_day )
               : split(/\s*,\s*/, $self->option('cutoff_day', 1) || '1');
}

1;
