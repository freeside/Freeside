package FS::part_event::Action::writeoff;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Write off bad debt with a credit entry.'; }

sub option_fields {
  ( 
    #'charge' => { label=>'Amount', type=>'money', }, # size=>7, },
    'reasonnum' => { 'label'        => 'Reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'R',
                   },
  );
}

sub default_weight { 65; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my $reasonnum = $self->option('reasonnum');

  my $error = $cust_main->credit( $cust_main->balance, \$reasonnum );
  die $error if $error;

  '';
}

1;
