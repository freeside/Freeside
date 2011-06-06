package FS::cdr::sonus;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Sonus',
  'weight'        => 525,
  'header'        => 0,     #0 default, set to 1 to ignore the first line, or
                            # to higher numbers to ignore that number of lines
  'type'          => 'csv', #csv (default), fixedlength or xls
  'sep_char'      => ',',   #for csv, defaults to ,
  'import_fields' => [
    'src', # also customer id
    'dst',
    _cdr_date_parser_maker('startdate'),
    _cdr_date_parser_maker('enddate'),
    _cdr_min_parser_maker,
    skip(12),
    sub { #rate
      my ($cdr, $rate) = @_;
      $cdr->upstream_price(sprintf("%.4f", $rate * $cdr->duration / 60));
    }
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
