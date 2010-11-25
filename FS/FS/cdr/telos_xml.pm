package FS::cdr::telos_xml;

use strict;
use vars qw( @ISA %info );
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Telos (XML)',
  'weight'        => 530,
  'type'          => 'xml',
  'xml_format'    => {
    'xmlrow' => [ 'Telos_CDRS', 'CDRecord' ],
    'xmlkeys' => [ qw(
      seq_num
      a_party_num
      b_party_num
      seize
      answer
      disc
      ) ],
  },

  'import_fields' => [
    'uniqueid',
    'src',
    'dst', # usually empty for some reason
    _cdr_date_parser_maker('startdate'),
    _cdr_date_parser_maker('answerdate'),
    _cdr_date_parser_maker('enddate'),
  ],

);

1;
