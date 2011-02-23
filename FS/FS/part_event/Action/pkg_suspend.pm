package FS::part_event::Action::pkg_suspend;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Suspend this package'; }

sub eventtable_hashref {
  { 'cust_pkg' => 1 };
}

sub option_fields {
  ( 
    'reasonnum' => { 'label'        => 'Reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'S',
                   },
  );
}

sub default_weight { 20; }

sub do_action {
  my( $self, $cust_pkg, $cust_event ) = @_;

  my $error = $cust_pkg->suspend( 'reason' => $self->option('reasonnum') );
  die $error if $error;
  
  '';
}

1;
