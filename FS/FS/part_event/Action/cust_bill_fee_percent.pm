package FS::part_event::Action::cust_bill_fee_percent;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Late fee (percentage of invoice)'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub event_stage { 'pre-bill'; }

sub option_fields {
  ( 
    'percent'  => { label=>'Percent', size=>2, },
    'reason'   => 'Reason',
    'taxclass' => { label=>'Tax class', type=>'select-taxclass', },
    'nextbill' => { label=>'Hold late fee until next invoice', type=>'checkbox', value=>'Y' },
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  my $amount =
    sprintf('%.2f', $cust_bill->owed * $self->option('percent') / 100 );

  my %charge = (
    'amount'     => $amount,
    'pkg'        => $self->option('reason'),
    'taxclass'   => $self->option('taxclass'),
  );

  $charge{'start_date'} = $cust_main->next_bill_date #unless its more than N months away?
    if $self->option('nextbill');

  my $error = $cust_main->charge( \%charge );

  die $error if $error;

  '';
}

1;
