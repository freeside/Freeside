package FS::part_pkg::flat_comission_cust;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch qsearchs);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);

%info = (
  'name' => 'Flat rate with recurring commission per active customer',
  'shortname' => 'Commission per active customer',
  'inherit_fields' => [ 'flat_comission', 'global_Mixin' ],
  'fields' => { },
  'fieldorder' => [ ],
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
