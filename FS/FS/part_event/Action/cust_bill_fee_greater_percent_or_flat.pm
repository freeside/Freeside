package FS::part_event::Action::cust_bill_fee_greater_percent_or_flat;

use strict;
use base qw( FS::part_event::Action::fee );
use Tie::IxHash;

sub description { 'Late fee (greater of percentage of invoice or flat fee)'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  my $class = shift;

  my $t = tie my %option_fields, 'Tie::IxHash', $class->SUPER::option_fields();
  $t->Shift; #assumes charge is first
  $t->Unshift( 'flat_fee'  => { label=>'Flat Fee', type=>'money', } );
  $t->Unshift( 'percent'   => { label=>'Percent', size=>2, } );

  %option_fields;
}

sub _calc_fee {
  my( $self, $cust_bill ) = @_;
  my $percent  = sprintf('%.2f', $cust_bill->owed * $self->option('percent') / 100 );
  my $flat_fee = $self->option('flat_fee');

  my $num = $flat_fee - $percent;
  if ($num == 0) {
    return($percent);
  } 
  elsif ($num > 0) {
    return($flat_fee);
  }
  else {
    return($percent);
  }
}

1;
