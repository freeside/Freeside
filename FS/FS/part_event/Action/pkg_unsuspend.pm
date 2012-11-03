package FS::part_event::Action::pkg_unsuspend;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Unsuspend this package'; }

sub eventtable_hashref {
  { 'cust_pkg' => 1,
    'svc_acct' => 1, };
}

sub default_weight { 20; }

sub do_action {
  my( $self, $object, $cust_event ) = @_;
  my $cust_pkg = $self->cust_pkg($object);

  my $error = $cust_pkg->unsuspend();
  die $error if $error;
  
  '';
}

1;
