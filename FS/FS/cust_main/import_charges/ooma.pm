package FS::cust_main::import_charges::ooma;

use strict;
use base qw( FS::cust_main::Import_Charges );
use vars qw ( %info );

# ooma fields
my @fields =  ('userfield1', 'userfield2', 'userfield3', 'userfield4', 'userfield5', 'userfield6', 'userfield7', 'userfield8', 'amount', 'userfield10', 'userfield11', 'userfield12', 'userfield13', 'userfield14', 'userfield15', 'userfield16', 'pkg', 'userfield18', 'custnum', 'userfield20', 'userfield21', 'userfield22', 'userfield23', 'userfield24', 'userfield25', );
# hash of charges (pkg) to charge.  if empty charge them all.
# '911 services' => '1',
my $charges = {};

%info = (
  'fields'   => [@fields],
  'charges'  => $charges,
  'name'     => 'Ooma',
  'weight'   => '10',
  'disabled' => '',	
);

1;