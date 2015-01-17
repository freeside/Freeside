package FS::part_event::Action::cust_bill_suspend;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Suspend packages on this invoice'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'reasonnum'    => { 'label'        => 'Reason',
                        'type'         => 'select-reason',
                        'reason_class' => 'S',
                      },
    'suspend_bill' => { 'label' => 'Continue recurring billing while suspended',
                        'type'  => 'checkbox',
                        'value' => 'Y',
                      },
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  my @err = $cust_bill->suspend(
    'reason'  => $self->option('reasonnum'),
    'options' => { 'suspend_bill' => $self->option('suspend_bill') },
  );

  die join(' / ', @err) if scalar(@err);

  return '';

}

1;
