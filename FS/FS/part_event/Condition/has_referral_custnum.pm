package FS::part_event::Condition::has_referral_custnum;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Customer has a referring customer'; }

sub condition {
  my($self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  $cust_main->referral_custnum;
}

sub condition_sql {
  #my( $class, $table ) = @_;

  "cust_main.referral_custnum IS NOT NULL";
}

1;
