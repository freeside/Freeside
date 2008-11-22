package FS::part_event::Action::cancel;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Cancel'; }

sub option_fields {
  ( 
    'reasonnum' => { 'label'        => 'Reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'C',
                   },
  );
}

sub default_weight { 20; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my $error = $cust_main->cancel( 'reason' => $self->option('reasonnum') );
  die $error if $error;
  
  '';
}

1;
