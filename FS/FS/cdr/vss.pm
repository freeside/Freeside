package FS::cdr::vss;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'VSS',
  'weight'        => 120,
  'header'        => 1,
  'import_fields' => [

        skip(1),        # Customer
        skip(1),        # i_customer
        'accountcode',  # account_id
        'src',          # caller
        'dst',          # called
        skip(2),        # reason
			# call id
        _cdr_date_parser_maker('startdate'),       # time
        'billsec',      # duration
        skip(3),        # ringtime
                        # status
                        # resller_charge
       'upstream_price',# customer_charge
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
