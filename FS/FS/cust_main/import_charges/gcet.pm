package FS::cust_main::import_charges::gcet;

use strict;
use base qw( FS::cust_main::Import_Charges );
use vars qw ( %info );

# gcet fields.
my @fields = ( 'userfield1', 'userfield2', 'userfield3', 'userfield4', 'userfield5', 'userfield6', 'userfield7', 'userfield8', 'userfield9', 'userfield10', 'amount', 'userfield12', 'userfield13', 'userfield14', 'userfield15', 'userfield16', 'userfield17', 'userfield18', 'pkg', 'userfield20', 'custnum', 'userfield22', 'userfield23', 'userfield24', 'userfield25', );
# hash of charges (pkg) to charge.  if empty charge them all.
# '911 services' => '1',
my $charges = {
  'DISABILITY ACCESS/ENHANCED 911 SERVICES SURCHARGE' => '1',
  'FEDERAL TRS FUND'                                  => '1',
  'FEDERAL UNIVERSAL SERVICE FUND'                    => '1',
  'STATE SALES TAX'                                   => '1',
};

%info = (
  'fields'   => [@fields],
  'charges'  => $charges,
  'name'     => 'Gcet',
  'weight'   => '30',
  'disabled' => '1',
);

1;