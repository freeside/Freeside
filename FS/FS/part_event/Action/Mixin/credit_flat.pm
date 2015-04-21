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
  my $warnref = $_[2]; #other input not used by credit_flat
  my $warning = $self->option('amount') ? '' : 'Amount set to zero ';
  $$warnref .= $warning if ref($warnref);
  return $self->option('amount');
}

1;
