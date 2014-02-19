package FS::part_event::Action::Mixin::fee;

use strict;
use base qw( FS::part_event::Action );

sub event_stage { 'pre-bill'; }

sub option_fields {
  (
    'feepart'  => { label     => 'Fee definition',
                    type      => 'select-table', #select-part_fee XXX
                    table     => 'part_fee',
                    hashref   => { disabled => '' },
                    name_col  => 'itemdesc',
                    value_col => 'feepart',
                    disable_empty => 1,
                  },
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_object, $cust_event ) = @_;

  die "no fee definition selected for event '".$self->event."'\n"
    unless $self->option('feepart');

  # mark the event so that the fee will be charged
  # the logic for calculating the fee amount is in FS::part_fee
  # the logic for attaching it to the base invoice/line items is in 
  # FS::cust_bill_pkg
  my $cust_event_fee = FS::cust_event_fee->new({
      'eventnum'    => $cust_event->eventnum,
      'feepart'     => $self->option('feepart'),
      'billpkgnum'  => '',
  });

  my $error = $cust_event_fee->insert;
  die $error if $error;

  '';
}

1;
