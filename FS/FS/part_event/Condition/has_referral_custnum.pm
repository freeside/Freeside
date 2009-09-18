package FS::part_event::Condition::has_referral_custnum;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Customer has a referring customer'; }

sub option_fields {
  (
    'active' => { 'label' => 'Referring customer is active',
                  'type'  => 'checkbox',
                  'value' => 'Y',
                },
  );
}

sub condition {
  my($self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  if ( $self->option('active') ) {

    return 0 unless $cust_main->referral_custnum;

    #check for no cust_main for referral_custnum? (deleted?)

    $cust_main->referral_custnum_cust_main->status eq 'active';

  } else {

    $cust_main->referral_custnum; # ? 1 : 0;

  }

}

sub condition_sql {
  #my( $class, $table ) = @_;

  "cust_main.referral_custnum IS NOT NULL";

  #XXX a bit harder to check active status here
}

1;
