package FS::cdr::windstream;

use strict;
use vars qw( @ISA %info %calltypes );
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%calltypes = (
  # numbers are arbitrary
  'IntraLata Calling' =>                              1 ,
  'Intrastate Calling' =>                             2  ,
  'Interstate Calling' =>                             3  ,
  'International Calling' =>                          4  ,
  'Intrastate Toll Free' =>                           5  ,
  'Interstate Toll Free' =>                           6  ,
  'Toll Free Canada' =>                               7  ,
  'Toll Free NANP' =>                                 8  ,
  'IntraLata Directory Assistance' =>                 9  ,
  'LD Directory Assistance' =>                        10 ,
  'Message Local Usage' =>                            11 ,
  'Operator Assistance' =>                            12 ,
  'Operator Services' =>                              13 ,
  'O- Assistance (Minus)' =>                          14 ,
  'O+ Assistance (Plus)' =>                           15 ,
  'IntraLata Toll 3rd Party' =>                       16 ,
  'IntraLata Toll Collect' =>                         17 ,
  'Third Number Billing' =>                           18 ,
  'Third Number Billing - Assisted' =>                19 ,
  'Three Way Calling (per use)' =>                    20 ,
  'Busy Connect (per use)' =>                         21 ,
  'Busy Line Interrupt (per use)' =>                  22 ,
  'Busy Line Verification (per use)' =>               23 ,
  'Call Forwarding Variable per access' =>            24 ,
  'Call Return (*69 per use)' =>                      25 ,
  'Call Trace (*per use)' =>                          26 ,
  'Conference Calling Feature' =>                     27 ,
  'Directory Assistance Call Completion (per use)' => 28 ,
);

$_ = lc($_) for keys(%calltypes);

%info = (
  'name'          => 'Windstream',
  'weight'        => 520,
  'header'        => 0,
  'sep_char'      => "\t",
  'import_fields' => [

    'accountcode',                        # Account Number
    'uniqueid',                           # Reference Number
    '',                                   # Call Type (see Service Type below)
    _cdr_date_parser_maker('answerdate'), # Answer Date
    '',                                   # Account Code--unused?
    '',                                   # CPN_DID
    'src',                                # From Number
    'upstream_src_regionname',            # From Location
    '',                                   # From Country
    'dst',                                # To Number
    'upstream_dst_regionname',            # To Location
    '',                                   # To Country Code
    '',                                   # Units
    'upstream_price',                     # Amount
    sub {                                 # Service Type
      my ($cdr, $field) = @_;
      $cdr->calltypenum($calltypes{$field} || '')
    },
    '',                                   # Payphone Indicator
    sub {                                 # TF Service Number
      # replace the To Number with this, if there is one
      my ($cdr, $field) = @_;
      $cdr->dst($field) if ( $field );
    },
  ],
);

1;
