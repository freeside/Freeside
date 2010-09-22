package FS::cdr::infinite;

use strict;
use vars qw( @ISA %info );
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Infinite Conferencing',
  'weight'        => 520,
  'header'        => 1,
  'type'          => 'csv',
  'sep_char'      => ',',
  'import_fields' => [
    'uniqueid',       # billid
    skip(3),          # confid, invoicenum, acctgrpid
    'accountcode',    # accountid ("Room Confirmation Number")
    skip(2),          # billingcode ("Room Billingcode"), confname
    skip(1),          # participant_type
    'startdate',      # starttime_t
    skip(2),          # startdate, starttime
    sub { my($cdr, $data, $conf, $param) = @_;
          $cdr->duration($data * 60);
          $cdr->billsec( $data * 60);
    },                # minutes
    'dst',            # dnis
    'src',            # ani
    skip(8),          # calltype, calltype_text, confstart_t, confstartdate,
                      # confstarttime, confminutes, conflegs, ppm
    'upstream_price', # callcost
    skip(13),         # confcost, rppm, rcallcost, rconfcost,
                      # auxdata[1..4], ldval, sysname, username, cec, pec
    'userfield',      # unnamed field
    ],

);

sub skip { map {''} (1..$_[0]) }

1;
