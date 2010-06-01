package FS::cdr::wip;

use strict;
use vars qw( @ISA %info );
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'WIP',
  'weight'        => 100,
  'header'        => 1,
  'type'          => 'csv',
  'sep_char'      => ':',
  'import_fields' => [
# All of these are based on the January 2010 version of the spec,
# except that we assume that before all the fields mentioned in the
# spec, there's a counter field.
    skip(4),          # counter, id, APCSJursID, RecordType
    sub { my($cdr, $data, $conf, $param) = @_;
          $param->{skiprow} = 1 if $data == 1;
          $cdr->uniqueid($data);
    },      # CDRID; is 1 for line charge records
    skip(1),          # AccountNumber; empty
    'charged_party',  # ServiceNumber
    skip(1),          # ServiceNumberType
    'src',            # PointOrigin
    'dst',            # PointTarget
    'calltypenum',    # Jurisdiction: need to remap
    _cdr_date_parser_maker('startdate'), #TransactionDate
    skip(3),          # BillClass, TypeIDUsage, ElementID
    'duration',       # PrimaryUnits
    skip(6),          # CompletionStatus, Latitude, Longitude, 
                      # OriginDescription, TargetDescription, RatePeriod
    'billsec',        # RatedUnits; seems to always be equal to PrimaryUnits
    skip(6),  #SecondsUnits, ThirdUnits, FileID, OriginalExtractSequenceNumber,
              #RateClass, #ProviderClass
    skip(8),  #ProviderID, CurrencyCode, EquipmentTypeCode, ClassOfServiceCode,
              #RateUnitsType, DistanceBandID, ZoneClass, CDRStatus
    'upstream_price', # ISPBuy
    skip(2),          # EUBuy, CDRFromCarrier
    ],

);

sub skip { map {''} (1..$_[0]) }

1;
