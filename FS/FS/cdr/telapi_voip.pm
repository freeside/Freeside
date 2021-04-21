package FS::cdr::telapi_voip;
use base qw( FS::cdr );

use strict;
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker );

%info = (
  'name'          => 'TeleAPI VoIP (CSV file)',
  'weight'        => 601,
  'header'        => 1,
  'type'          => 'csv',
  'import_fields' => [
    _cdr_date_parser_maker('startdate', 'gmt'=>1 ),  # date gmt
    'src',                                           # source
    'dst',                                           # destination
    'clid',                                          # callerid
    'disposition',                                   # hangup code
    'userfield',                                     # sip account
    'src_ip_addr',                                   # orig ip
    'billsec',                                       # duration
    skip(1),                                  # per minute (add "upstream_rate"?
    'upstream_price',                                # call cost
    'dcontext',                                      # type
    'uniqueid',                                      # uuid
    'lastapp',                                       # direction
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
