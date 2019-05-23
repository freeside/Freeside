package FS::cdr::telapi_voip_csv;
use base qw( FS::cdr );

use strict;
use vars qw( @ISA %info $CDR_TYPES );
use FS::Record qw( qsearch );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'telapi_voip (csv file)',
  'weight'        => 601,
  'header'        => 1,
  'type'          => 'csv',
  'import_fields' => [
    skip(1),                              # Inbound/Outbound
    _cdr_date_parser_maker('startdate'),  # date
    skip(1),                              # cost per minute
    'upstream_price',                     # call cost
    'billsec',                            # duration
    'src',                                # source
    'dst',                                # destination
    skip(1),                              # hangup code
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
