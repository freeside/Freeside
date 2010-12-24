package FS::part_pkg::flat_comission;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Flat rate with recurring commission per (any) active package',
  'shortname' => 'Commission per (any) active package',
  'inherit_fields' => [ 'global_Mixin' ],
  'fields' => {
    'comission_amount' => { 'name' => 'Commission amount per month (per active package)',
                            'default' => 0,
                          },
    'comission_depth'  => { 'name' => 'Number of layers',
                            'default' => 1,
                          },
    'reason_type'      => { 'name' => 'Reason type for commission credits',
                            'type' => 'select',
                            'select_table' => 'reason_type',
                            'select_hash'  => { 'class' => 'R' },
                            'select_key'   => 'typenum',
                            'select_label' => 'type',
                          },
  },
  'fieldorder' => [ 'comission_depth', 'comission_amount', 'reason_type' ],
  #'setup' => 'what.setup_fee.value',
  #'recur' => '\'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar($cust_pkg->cust_main->referral_cust_pkg(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
  'weight' => 62,
);

sub calc_recur {
  my($self, $cust_pkg ) = @_;

  my $amount = $self->option('comission_amount');
  my $num_active = scalar(
    $cust_pkg->cust_main->referral_cust_pkg( $self->option('comission_depth') )
  );

  my $commission = sprintf('%.2f', $amount*$num_active);

  if ( $commission > 0 ) {

    my $error =
      $cust_pkg->cust_main->credit( $commission, "commission",
                                    'reason_type'=>$self->option('reason_type'),
                                  );
    die $error if $error;

  }

  $self->option('recur_fee');
}

sub can_discount { 0; }

1;
