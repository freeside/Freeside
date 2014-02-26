package FS::part_event::Action::Mixin::fee;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearch );

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
  ),

}

sub default_weight { 10; }

sub hold_until_bill { 1 }

sub do_action {
  my( $self, $cust_object, $cust_event ) = @_;

  my $feepart = $self->option('feepart')
    or die "no fee definition selected for event '".$self->event."'\n";
  my $tablenum = $cust_object->get($cust_object->primary_key);

  # see if there's already a pending fee for this customer/invoice
  my @existing = qsearch({
      table     => 'cust_event_fee',
      addl_from => 'JOIN cust_event USING (eventnum)',
      hashref   => { feepart    => $feepart,
                     billpkgnum => '' },
      extra_sql => " AND tablenum = $tablenum",
  });
  if (scalar @existing > 0) {
    warn $self->event." event, object $tablenum: already scheduled\n"
      if $FS::part_fee::DEBUG;
    return;
  }

  # mark the event so that the fee will be charged
  # the logic for calculating the fee amount is in FS::part_fee
  # the logic for attaching it to the base invoice/line items is in 
  # FS::cust_bill_pkg
  my $cust_event_fee = FS::cust_event_fee->new({
      'eventnum'    => $cust_event->eventnum,
      'feepart'     => $feepart,
      'billpkgnum'  => '',
      'nextbill'    => $self->hold_until_bill ? 'Y' : '',
  });

  my $error = $cust_event_fee->insert;
  die $error if $error;

  '';
}

1;
