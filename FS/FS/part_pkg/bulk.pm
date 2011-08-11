package FS::part_pkg::bulk;
use base qw( FS::part_pkg::bulk_Common );

use strict;
use vars qw($DEBUG $me %info);
use Date::Format;
use List::Util qw( max );
use FS::Conf;

$DEBUG = 0;
$me = '[FS::part_pkg::bulk]';

%info = (
  'name' => 'Bulk billing based on number of active services (during billing period)',
  'inherit_fields' => [ 'bulk_Common', 'global_Mixin' ],
  'fields' => {
    'no_prorate'    => { 'name' => 'Don\'t prorate recurring fees on services '.
                                   'active for a partial month',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'no_prorate' ],
  'weight' => 51,
);


sub _bulk_cust_svc {
  my( $self, $cust_pkg, $sdate ) = @_;
                       #   END      START
  $cust_pkg->h_cust_svc( $$sdate, $cust_pkg->last_bill );
}

sub _bulk_setup {
  my( $self, $cust_pkg, $h_cust_svc ) = @_;
  ($h_cust_svc->date_inserted < $cust_pkg->last_bill)
    ? $self->option('svc_setup_fee')
    : 0;
}

sub _bulk_recur {
  my( $self, $cust_pkg, $h_cust_svc, $sdate ) = @_;

  return ($self->option('svc_recur_fee'), '')
    if $self->option('no_prorate',1);

  my $last_bill = $cust_pkg->last_bill;
  my $svc_start = max( $h_cust_svc->date_inserted, $last_bill);
  my $svc_end = $h_cust_svc->date_deleted;
  $svc_end = ( !$svc_end || $svc_end > $$sdate ) ? $$sdate : $svc_end;

  my $recur_charge = $self->option('svc_recur_fee') 
                                   * ( $svc_end - $svc_start )
                                   / ( $$sdate  - $last_bill );

  return (0, '') unless $recur_charge;

  my $svc_details .= ' ('.  time2str('%x', $svc_start).
                  ' - '. time2str('%x', $svc_end  ). ')';

  ( $recur_charge, $svc_details );

}

1;

