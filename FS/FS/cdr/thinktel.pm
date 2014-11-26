package FS::cdr::thinktel;

use strict;
use base qw( FS::cdr );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

our %info = (
  'name'          => 'Thinktel',
  'weight'        => 541,
  'header'        => 1,     #0 default, set to 1 to ignore the first line, or
                            # to higher numbers to ignore that number of lines
  'type'          => 'csv', #csv (default), fixedlength or xls
  'sep_char'      => ',',   #for csv, defaults to ,
  'disabled'      => 0,     #0 default, set to 1 to disable

  #listref of what to do with each field from the CDR, in order
  'import_fields' => [
    'charged_party',
    'src',
    'dst',
    _cdr_date_parser_maker('startdate'),
    'billsec', # rounded call duration
    'dcontext', # Usage Type: 'Local', 'Canada', 'Incoming', ...
    'upstream_price',
    'upstream_src_regionname',
    'upstream_dst_regionname',
    '', # upstream rate per minute
    '', # "Label"
    # raw seconds, to one decimal place
    sub { my ($cdr, $sec) = @_;
          $cdr->set('duration', sprintf('%.0f', $sec));
        },
    # newly added fields of unclear meaning:
    # Subscription (UUID, seems to correspond to charged_party)
    # Call Type (always "Normal" thus far)
    # Carrier (always empty)
    # Alt Destination Name (always empty)
  ],
);

1;

