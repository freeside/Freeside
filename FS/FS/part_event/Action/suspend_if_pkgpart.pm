package FS::part_event::Action::suspend_if_pkgpart;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Suspend packages'; }

#i should be deprecated in favor of using the if_pkgpart condition

sub option_fields {
  ( 
    'if_pkgpart' => { 'label'    => 'Suspend packages:',
                      'type'     => 'select-part_pkg',
                      'multiple' => 1,
                    },
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

  my @err = $cust_main->suspend_if_pkgpart( {
    'pkgparts' => [ split(/\s*,\s*/, $self->option('if_pkgpart') ) ],
    'reason'   => $self->option('reasonnum'),
  } );

  die join(' / ', @err) if scalar(@err);

  '';
}

1;
