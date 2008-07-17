package FS::cdr::genband_meetme;

use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Genband (Tekelec) Meet-Me Conference', #'Genband G6 (Tekelec T6000) Meet-Me Conference Log Records',
  'weight'        => 145,
  'disabled'      => 1,
  'import_fields' => [
  ],
);

1;
