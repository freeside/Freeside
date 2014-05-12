package FS::cdr::orcon;

use strict;
use vars qw( @ISA %info);
use FS::cdr;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Orcon',
  'weight'        => 120,
  'header'        => 1,
  'import_fields' => [

        skip(2),        #id
                        #billing period
        'accountcode',  #account number
        skip(2),        #username
                        #service id
        'calldate',     #date
        skip(1),        #tariff region
        'src',          #originating number
        'dst',          #terminating number
        'duration',      #duration actual
        'billsec',	#duration billed
        skip(1),        #discount
        'upstream_price',#charge

  ],
);

sub skip { map {''} (1..$_[0]) }

1;

