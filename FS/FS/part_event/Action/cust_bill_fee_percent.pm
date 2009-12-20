package FS::part_event::Action::cust_bill_fee_percent;

use strict;
use base qw( FS::part_event::Action::fee );
use Tie::IxHash;

sub description { 'Late fee (percentage of invoice)'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  my $class = shift;

  my $t = tie my %option_fields, 'Tie::IxHash', $class->SUPER::option_fields();
  $t->Shift; #assumes charge is first
  $t->Unshift( 'percent'  => { label=>'Percent', size=>2, } );

  %option_fields;
}

sub _calc_fee {
  my( $self, $cust_bill ) = @_;
  sprintf('%.2f', $cust_bill->owed * $self->option('percent') / 100 );
}

1;
