package FS::part_event::Action::cust_bill_fee_percent;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Late fee (percentage of invoice)'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  ( 
    'percent' => { label=>'Percent', size=>2, },
    'reason'  => 'Reason',
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  my $error = $cust_main->charge(
    sprintf('%.2f', $cust_bill->owed * $self->option('percent') / 100 ),
    $self->option('reason')
  );
  die $error if $error;

  '';
}

1;
