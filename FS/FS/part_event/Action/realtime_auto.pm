package FS::part_event::Action::realtime_auto;

use strict;
use base qw( FS::part_event::Action );

sub description {
  #'Run card with a <a href="http://420.am/business-onlinepayment/">Business::OnlinePayment</a> realtime gateway';
  'Run card or check with a Business::OnlinePayment realtime gateway';
}

sub eventtable_hashref {
  { 'cust_bill' => 1,
    'cust_main' => 1,
  };
}

sub default_weight { 30; }

sub do_action {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my %opt = ('cc_surcharge_from_event' => 1);

  my $amount;
  my $balance = $cust_main->balance;
  if ( ref($object) eq 'FS::cust_main' ) {
    $amount = $balance;
  } elsif ( ref($object) eq 'FS::cust_bill' ) {
    $amount = ( $balance < $object->owed ) ? $balance : $object->owed;
    $opt{'invnum'} = $object->invnum;
  } else {
    die 'guru meditation #5454.au';
  }

  $cust_main->realtime_cust_payby( 'amount' => $amount, %opt, );

}

1;
