package FS::cdr::vitelity;

use strict;
use vars qw( @ISA %info );
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Vitelity',
  'weight'        => 100,
  'header'        => 1,
  'import_fields' => [
    # Cheers to Vitelity for their concise, readable CDR format.
    _cdr_date_parser_maker('startdate'),
    'src',
    'dst',
    'duration',
    'clid',
    'disposition',
    'upstream_price',
    ],
);

1;
