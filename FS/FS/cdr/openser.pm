package FS::cdr::openser;

use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'OpenSER',
  'weight'        => 15,
  'header'        => 1,
  'import_fields' => [
    _cdr_date_parser_maker('startdate'),
    _cdr_date_parser_maker('enddate'),
    'src',
    'dst',
    'duration',
    'channel',
    'dstchannel',
  ],
);

1;
