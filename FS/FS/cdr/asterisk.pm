package FS::cdr::asterisk;

use vars qw(@ISA %info);
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

#http://www.the-asterisk-book.com/unstable/funktionen-cdr.html
my %amaflags = (
  DEFAULT       => 0,
  OMIT          => 1, #asterisk 1.4+
  IGNORE        => 1, #asterisk 1.2
  BILLING       => 2, #asterisk 1.4+
  BILL          => 2, #asterisk 1.2
  DOCUMENTATION => 3,
  #? '' => 0,
);

%info = (
  'name'          => 'Asterisk',
  'weight'        => 10,
  'import_fields' => [
    'accountcode',
    'src',
    'dst',
    'dcontext',
    'clid',
    'channel',
    'dstchannel',
    'lastapp',
    'lastdata',
    _cdr_date_parser_maker('startdate'),
    _cdr_date_parser_maker('answerdate'),
    _cdr_date_parser_maker('enddate'),
    'duration',
    'billsec',
    'disposition',
    sub { my($cdr, $amaflags) = @_; $cdr->amaflags($amaflags{$amaflags}); },
    'uniqueid',
    'userfield',
  ],
);

1;
