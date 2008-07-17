package FS::cdr::unitel;

use vars qw(@ISA %info);
use FS::cdr;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Unitel/RSLCOM',
  'weight'        => 500,
  'import_fields' => [
    'uniqueid',
    #'cdr_type',
    'cdrtypenum',
    'calldate', # may need massaging?  huh maybe not...
    #'billsec', #XXX duration and billsec?
                sub { $_[0]->billsec(  $_[1] );
                      $_[0]->duration( $_[1] );
                    },
    'src',
    'dst', # XXX needs to have "+61" prepended unless /^\+/ ???
    'charged_party',
    'upstream_currency',
    'upstream_price',
    'upstream_rateplanid',
    'distance',
    'islocal',
    'calltypenum',
    'startdate',  #XXX needs massaging
    'enddate',    #XXX same
    'description',
    'quantity',
    'carrierid',
    'upstream_rateid',
  ]
);

1;
