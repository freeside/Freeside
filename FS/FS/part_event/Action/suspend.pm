package FS::part_event::Action::suspend;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Suspend'; }

sub option_fields {
  ( 
    'reasonnum' => { 'label'        => 'Reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'S',
                   },
  );
}

sub default_weight { 10; }

sub do_action {
  my( $self, $cust_object ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  my @err = $cust_main->suspend( 'reason' => $self->option('reasonnum') );

  die join(' / ', @err) if scalar(@err);

  '';

}

1;
