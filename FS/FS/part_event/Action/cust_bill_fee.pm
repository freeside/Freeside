package FS::part_event::Action::cust_bill_fee;

use strict;
use base qw( FS::part_event::Action::Mixin::fee );

sub description { 'Charge a fee based on this invoice'; }

sub eventtable_hashref {
    { 'cust_bill' => 1 };
}

sub option_fields {
  (
    __PACKAGE__->SUPER::option_fields,
    'nextbill'  => { label    => 'Hold fee until the customer\'s next bill',
                     type     => 'checkbox',
                     value    => 'Y'
                   },
  )
}

# it makes sense for this to be optional for previous-invoice fees
sub hold_until_bill {
  my $self = shift;
  $self->option('nextbill');
}

1;
