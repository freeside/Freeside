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
      record_type
      seq_num
      a_party_num
      b_party_num
      seize
      answer
      disc
      ) ],
  },

  'import_fields' => [
    sub { my($cdr, $data, $conf, $param) = @_;
          $cdr->cdrtypenum($data);
          # CDR type 2 = SMS records, set billsec = 1 so that 
          # they'll be charged under per-call rating
          $cdr->billsec(1) if ( $data == 2 );
        },
    'uniqueid',
    'src',
    'dst', # usually empty for some reason
    _cdr_date_parser_maker('startdate'),
    _cdr_date_parser_maker('answerdate'),
    _cdr_date_parser_maker('enddate'),
  ],

);

1;
