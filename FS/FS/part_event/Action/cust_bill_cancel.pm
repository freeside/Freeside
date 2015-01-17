package FS::part_event::Action::cust_bill_cancel;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Cancel packages on this invoice'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  (
    'reasonnum'    => { 'label'        => 'Reason',
                        'type'         => 'select-reason',
                        'reason_class' => 'C',
                      },
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  my @err = $cust_bill->cancel(
    'reason'  => $self->option('reasonnum'),
  );

  die join(' / ', @err) if scalar(@err);

  return '';
}

1;
