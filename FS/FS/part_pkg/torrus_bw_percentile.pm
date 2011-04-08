package FS::part_pkg::torrus_bw_percentile;

use strict;
use base qw( FS::part_pkg::torrus_Common );
use List::Util qw(max);

our %info = (
  'name'      => '95th percentile billing based on the integrated Torrus NMS',
  'shortname' => 'Bandwidth (95th percentile)',
  'weight'    => 54.5, #:/
  'inherit_fields' => [ 'flat', 'global_Mixin' ],
  'fields' => {
    'recur_temporality' => { 'disabled' => 1 },
    'sync_bill_date'    => { 'disabled' => 1 },
    'cutoff_day'        => { 'disabled' => 1 },
    'base_mbps'         => { 'name'    => 'Included megabytes/sec (95th percentile)',
                             'default' => 0,
                           },
    'mbps_rate'         => { 'name'    => 'Charge per megabyte/sec (95th percentile)',
                             'default' => 0,
                           },
  },
  'fieldorder' => [ qw( base_mbps mbps_rate ) ],
  'freq' => 'm',
);

sub _torrus_name  { '95TH_PERCENTILE'; }
sub _torrus_base  { 'base_mbps'; }
sub _torrus_rate  { 'mbps_rate'; }
sub _torrus_label { 'mbps'; };

1;
