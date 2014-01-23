package FS::cdr::aapt;

use strict;
use base qw( FS::cdr );
use vars qw ( %info );
use FS::cdr qw(_cdr_date_parser_maker);

my %CURRENCY = ( #Table 2.1.3
  1 => 'AUD',
  2 => 'USD',
  3 => 'AUD',
);

my %UNIT_SCALE = ( #Table 2.1.4
  100 => 1,     # seconds
  101 => 0.1,   # tenths
  120 => 60,    # minutes
  130 => 3600,  # hours
  #(irrelevant, because we don't yet support these usage types, but still)
  200 => 1,     # bytes
  201 => 2**10, # KB
  202 => 2**20, # MB
  203 => 2**30, # GB
  401 => 2**10 * 1000, # "decimal MB"
  402 => 2**20 * 1000, # "decimal GB"
  451 => 1,     # Kbps--conveniently the same as our base unit
  452 => 1000,  # Mbps (decimal)
);

%info = (
  'name'          => 'AAPT CTOP',
  'weight'        => 600,
  'header'        => 1,
  'type'          => 'fixedlength',
  'row_callback'  => sub { $DB::single = 1; }, #XXX
  'parser_opt'    => { trim => 1 },
  'fixedlength_format' => [qw(
    record_type:6:1:6
    transaction_id:20R:7:26
    product_id:6R:27:32
    usage_type:6R:33:38
    id_type:6R:39:44
    id_value:48R:45:92
    trans_time:14:93:106
    sec_time:14:107:120
    target:24R:121:144
    origin:24R:145:168
    rated_units:10R:169:178
    rated_price:18R:179:196
    jurisdiction:18R:197:214
    fnn:18R:215:232
    foreign_amount:18R:233:250
    currency:6R:251:256
    recipient:10R:257:266
    completion:3R:267:269
    record_id:22R:270:291
    raw_units:10R:292:301
    raw_unittype:6R:302:307
    rated_unittype:6R:308:313
    base_amount:18R:314:331
    second_units:10R:332:341
    third_units:10R:342:351
    special1:255:352:606
    special2:96:607:702
    service_type:6:703:708
    sec_id_type:6:709:714
    sec_id_value:48:715:762
    unused:238:763:1000
  )],
  'import_fields' => [
    sub {                   # record type
      my ($cdr, $data, $conf, $param) = @_;
      $param->{skiprow} = 1 if $data ne 'PWTDET'; # skip non-detail records
    },
    '',                     # transaction ID
    '',                     # product ID (CPRD)
    'calltypenum',          # usage ID (CUSG)
    sub {                   # ID type
      my ($cdr, $data, $conf, $param) = @_;
      if ($data != 1) {
        warn "AAPT: service ID type is not telephone number.\n";
        $param->{skiprow} = 1;
      }
    },
    'charged_party',        # ID value (phone number, if ID type = 1)
    _cdr_date_parser_maker('startdate'),  # trans date/time
    '',                     # secondary date (unused?)
    'dst',                  # Target (B-party)
    'src',                  # Origin (A-party)
    'billsec',              # Rated units (may need unit scaling)
    sub {                   # Amount charged
      my ($cdr, $data) = @_;
      $cdr->set('upstream_price', sprintf('%.5f', $data/100));
    },
    'dcontext',             # Jurisdiction code; we use dcontext for this
    '',                     # Full National Number (unused?)
    '',                     # "Foreign Amount"
    sub {                   # Currency
      my ($cdr, $data) = @_;
      $cdr->set('upstream_currency', $CURRENCY{$data});
    },
    '',                     # Reseller account number
    '',                     # Completion status
    'uniqueid',             # CTOP Record ID
    'duration',             # Raw units
    sub {                   # Raw unit type
      my ($cdr, $data) = @_;
      if (exists($UNIT_SCALE{$data})) {
        $cdr->set('duration',
          sprintf('%.0f', $cdr->get('duration') * $UNIT_SCALE{$data})
        );
      }
    },
    sub {                   # Rated unit type
      my ($cdr, $data) = @_;
      if (exists($UNIT_SCALE{$data})) {
        $cdr->set('billsec',
          sprintf('%.0f', $cdr->get('billsec') * $UNIT_SCALE{$data})
        );
      }
    },
    # trailing fields we don't care about
  ], #import_fields
);

1;
