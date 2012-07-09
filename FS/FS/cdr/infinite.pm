package FS::cdr::infinite;

use strict;
use vars qw( @ISA %info );
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

my $date_parser = _cdr_date_parser_maker('startdate');

%info = (
  'name'          => 'Infinite Conferencing',
  'weight'        => 520,
  'header'        => 1,
  'type'          => 'csv',
  'sep_char'      => ',',
  'import_fields' => [
    'uniqueid',       # A. billid
    skip(3),          # B-D. confid, invoicenum, acctgrpid
    skip(1),          # E. accountid ("Room Confirmation Number")
    skip(2),          # F-G. billingcode ("Room Billingcode"), confname
    skip(1),          # H. participant_type
    skip(1),          # I. starttime_t - timezone is unreliable
    sub {             # J. startdate
      my ($cdr, $data, $conf, $param) = @_;
      $param->{'date_part'} = $data; # stash this and combine with the time
      '';
    },
    sub {             # K. starttime
      my ($cdr, $data, $conf, $param) = @_;
      my $datestring = delete($param->{'date_part'}) . ' ' . $data;
      &{ $date_parser }($cdr, $datestring);
    },
    sub { my($cdr, $data, $conf, $param) = @_;
          $cdr->duration($data * 60);
          $cdr->billsec( $data * 60);
    },                # L. minutes
    skip(1),          # M. dnis
    'src',            # N. ani
    'dst',            # O. calltype
    skip(7),          # P-V. calltype_text, confstart_t, confstartdate, 
                      # confstarttime, confminutes, conflegs, ppm
    'upstream_price', # W. callcost
    skip(11),         # X-AH. confcost, rppm, rcallcost, rconfcost,
                      # auxdata[1..4], ldval, sysname, username
    'accountcode',    # AI. Chairperson Entry Code
    skip(1),          # AJ. Participant Entry Code
    'description',    # AK. contact name
  ],

);

sub skip { map {''} (1..$_[0]) }

1;
