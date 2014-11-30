package FS::part_event::Action::Mixin::credit_flat;

# credit_flat: return a fixed amount for _calc_credit, specified in the 
# options

use strict;

sub option_fields {
  (
    'reasonnum' => { 'label'        => 'Credit reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'R',
                   },
    'amount'    => { 'label'        => 'Credit amount',
                     'type'         => 'money',
                   },
  );
}

sub _calc_credit {
  my $self = shift;
  $self->option('amount');
}

1;
