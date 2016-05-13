package FS::cdr::conexiant;
use base qw( FS::cdr );

use strict;
use vars qw( %info );
use FS::Record qw( qsearchs );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Conexiant',
  'weight'        => 600,
  'header'        => 1,
  'type'          => 'csv',
  'import_fields' => [
    skip(3),               #LookupError,Direction,LegType
    sub {                  #CallId
      my($cdr,$value,$conf,$param) = @_;
      if (qsearchs('cdr',{'uniqueid' => $value})) {
        $param->{'skiprow'} = 1;
        $param->{'empty_ok'} = 1;
      } else {
        $cdr->uniqueid($value);
      }
    },
    'upstream_rateplanid', #ClientRateSheetId
    skip(1),               #ClientRouteId
    'src',                 #SourceNumber
    skip(1),               #RawNumber
    'dst',                 #DestNumber
    skip(1),               #DestLRN
    _cdr_date_parser_maker('startdate'),  #CreatedOn
    _cdr_date_parser_maker('answerdate'), #AnsweredOn
    _cdr_date_parser_maker('enddate'),    #HangupOn
    skip(4),               #CallCause,SipCode,Price,USFCharge
    'upstream_price',      #TotalPrice
    _cdr_min_parser_maker('billsec'),     #PriceDurationMins
    skip(2),               #SipEndpointId, SipEndpointName
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
