package FS::part_pkg::flat_comission_cust;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Flat rate with recurring commission per active customer',
  'shortname' => 'Commission per active customer',
  'fields' => {
    'setup_fee' => { 'name' => 'Setup fee for this package',
                     'default' => 0,
                   },
    'recur_fee' => { 'name' => 'Recurring fee for this package',
                     'default' => 0,
                   },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
    'comission_amount' => { 'name' => 'Commission amount per month (per active customer)',
                            'default' => 0,
                          },
    'comission_depth'  => { 'name' => 'Number of layers',
                            'default' => 1,
                          },
    'reason_type'      => { 'name' => 'Reason type for commission credits',
                            'type' => 'select_table',
                            'select_table' => 'reason_type',
                            'select_hash'  => { 'class' => 'R' },
                            'select_key'   => 'typenum',
                            'select_label' => 'type',
                          },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'unused_credit', 'comission_depth', 'comission_amount', 'reason_type' ],
  #'setup' => 'what.setup_fee.value',
  #'recur' => '\'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar($cust_pkg->cust_main->referral_cust_main_ncancelled(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
  'weight' => '60',
);

sub calc_recur {
  my($self, $cust_pkg ) = @_;

  my $amount = $self->option('comission_amount');
  my $num_active = scalar(
    $cust_pkg->cust_main->referral_cust_main_ncancelled(
      $self->option('comission_depth')
    )
  );

  if ( $amount && $num_active ) {
    my $error =
      $cust_pkg->cust_main->credit( $amount*$num_active, "commission",
                                    'reason_type'=>$self->option('reason_type'),
                                  );
    die $error if $error;
  }

  $self->option('recur_fee');
}

sub can_discount { 0; }

1;
