package FS::part_event::Action::fee;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Late fee (flat)'; }

sub option_fields {
  ( 
    'charge'   => { label=>'Amount', type=>'money', }, # size=>7, },
    'reason'   => 'Reason',
    'taxclass' => { label=>'Tax class', type=>'select-taxclass', },
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my $error = $cust_main->charge( {
    'amount'   => $self->option('charge'),
    'pkg'      => $self->option('reason'),
    'taxclass' => $self->option('taxclass')
    #'start_date' => $cust_main->next_bill_date, #unless its more than N months away?
  } );

  die $error if $error;

  '';
}

1;
