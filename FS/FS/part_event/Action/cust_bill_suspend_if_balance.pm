package FS::part_event::Action::cust_bill_suspend_if_balance;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Suspend if balance (this invoice and previous) over'; }

sub deprecated { 1; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  ( 
    'balanceover' => { label=>'Balance over', type=>'money', }, # size=>7 },
    'reasonnum' => { 'label'        => 'Reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'S',
                   },
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_bill ) = @_;

  #my $cust_main = $self->cust_main($cust_bill);
  my $cust_main = $cust_bill->cust_main;

  my @err = $cust_bill->cust_suspend_if_balance_over(
    $self->option('balanceover'),
    'reason' => $self->option('reasonnum'),
  );

  die join(' / ', @err) if scalar(@err);

  '';
}

1;
