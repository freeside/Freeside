package FS::cust_main::import_charges::simple;

use strict;
use base qw( FS::cust_main::Import_Charges );
use vars qw ( %info );

# simple field format
my @fields =  ('custnum', 'agent_custid', 'amount', 'pkg');
# hash of charges (pkg) to charge.  if empty charge them all.
# '911 services' => '1',
my $charges = {};

%info = (
  'fields'   => [@fields],
  'charges'  => $charges,
  'name'     => 'Simple',
  'weight'   => '1',
  'disabled' => '',
);

1;