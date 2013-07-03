package FS::part_event::Condition::pkg_reason_type;
use base qw( FS::part_event::Condition );

use strict;
use Tie::IxHash;
#use FS::Record qw( qsearch );

sub description {
  'Package Reason Type';
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
      'svc_acct'  => 1,
    };
}

tie my %actions, 'Tie::IxHash',
  #'adjourn' =>
  'susp'   => 'Suspension',
  #'expire' =>
  'cancel' => 'Cancellation'
;

sub option_fields {
  (
    'action'  => { 'label'    => 'Package Action',
                   'type'     => 'select',
                   'options'  => [ keys %actions ],
                   'labels'   => \%actions,
                 },
    'typenum' => { 'label'    => 'Reason Type',
                   'type'     => 'select-reason_type',
                   'multiple' => 1,
                 },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_pkg = $self->cust_pkg($object);

  my $reason = $cust_pkg->last_reason( $self->option('action') )
    or return 0;

  my $hashref = $self->option('typenum') || {};
  $hashref->{ $reason->reason_type };
}

#sub condition_sql {
#  my( $self, $table ) = @_;
#
#}

1;
