package FS::part_pkg::torrus_bw_usage;

use strict;
use base qw( FS::part_pkg::torrus_Common );
use List::Util qw(max);

our %info = (
  'name'      => 'Volume billing based on the integrated Torrus NMS',
  'shortname' => 'Bandwidth (volume)',
  'weight'    => 54.7, #:/
  'inherit_fields' => [ 'flat', 'global_Mixin' ],
  'fields' => {
    'recur_temporality' => { 'disabled' => 1 },
    'sync_bill_date'    => { 'disabled' => 1 },
    'cutoff_day'        => { 'disabled' => 1 },
    'base_gb'           => { 'name'    => 'Included gigabytes',
                             'default' => 0,
                           },
    'gb_rate'           => { 'name'    => 'Charge per gigabyte',
                             'default' => 0,
                           },
  },
  'fieldorder' => [ qw( base_gb gb_rate ) ],
  'freq' => 'm',
);

sub _torrus_name  { 'VOLUME'; }
sub _torrus_base  { 'base_gb'; }
sub _torrus_rate  { 'gb_rate'; }
sub _torrus_label { 'gb'; };

1;
