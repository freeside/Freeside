package FS::part_pkg::bulk_simple;
use base qw( FS::part_pkg::bulk_Common );

use strict;
use vars qw($DEBUG $me %info);
use Date::Format;
use FS::Conf;
use FS::cust_svc_option;

$DEBUG = 0;
$me = '[FS::part_pkg::bulk]';

%info = (
  'name' => 'Bulk billing based on number of active services (at invoice generation)',
  'inherit_fields' => [ 'bulk_Common', 'global_Mixin' ],
  'weight' => 50,
);

sub _bulk_cust_svc {
  my( $self, $cust_pkg, $sdate ) = @_;
  $cust_pkg->cust_svc;
}

sub _bulk_setup {
  my( $self, $cust_pkg, $cust_svc ) = @_;
  return 0 if $cust_svc->option('bulk_setup');

  my $bulk_setup = new FS::cust_svc_option {
    'svcnum'      => $cust_svc->svcnum,
    'optionname'  => 'bulk_setup',
    'optionvalue' => time, #invoice date?
  };
  my $error = $bulk_setup->insert;
  die $error if $error;

  $self->option('svc_setup_fee');
}

sub _bulk_recur {
  my( $self, $cust_pkg, $cust_svc ) = @_;
  ( $self->option('svc_recur_fee'), '' );
}

1;

