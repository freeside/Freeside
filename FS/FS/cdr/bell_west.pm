package FS::cdr::bell_west;

use strict;
use base qw( FS::cdr );
use vars qw( %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
#use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Bell West',
  'weight'        => 210,
  'header'        => 1,
  'type'          => 'xls',

  'import_fields' => [

    # CDR FIELD / REQUIRED / Notes

    # CHG TYPE / No / Internal Code only (no need to import)
    sub {},

    # ACCOUNT # / No / Internal Number only (no need to import)
    sub {},

    # DATE / Yes / "DATE"   Excel date format MM/DD/YYYY
    # XXX false laziness w/troop.pm
    sub { my($cdr, $date) = @_;

          my $datetime = DateTime::Format::Excel->parse_datetime( $date );
          $tmp_mon  = $datetime->mon_0;
          $tmp_mday = $datetime->mday;
          $tmp_year = $datetime->year;
        },

    # CUST NO / Yes / "TIME"    "075959" Text based time
    # Note: This is really the start time but Bell header says "Cust No" which
    #       is wrong
    sub { my($cdr, $time) = @_;
          #my($sec, $min, $hour, $mday, $mon, $year)= localtime($cdr->startdate);
          $time =~ /^(\d{2})(\d{2})(\d{2})$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal($3, $2, $1 ,$mday, $mon, $year) );
          $cdr->startdate(
            timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year)
          );
        },

    # BTN / Yes / Main billing number but not DID or real number
    # (put in SRC field)
    'src',

    # ORIG CITY / No / We will use your Freeside rating and description name
    'channel',

    # TERM / YES / All calls should be billed, however all calls are
    #              missing "1+" and "011+" & DIR ASST = "411"
    'dst',

    # TERM CITY / No / We will use your Freeside rating and description name
    'dstchannel',

    # WTN / Yes / Bill to number (put in "charged_party")
    'charged_party',

    # CODE / Yes / Account Code (security) and we need on invoice
    'accountcode',

    # PROV/COUNTRY / No / We will use your Freeside rating and description name
    # (but use this to add "011" for "International" calls)
    sub { my( $cdr, $prov ) = @_;
          my $pre = ( $prov =~ /^\s*International\s*/i ) ? '011' : '1';
          $cdr->dst( $pre. $cdr->dst ) unless $cdr->dst =~ /^$pre/;
        },

    # CALL TYPE / Possibly / Not sure if you need this to determine correct
    #                        billing method ?
    # DDD normal call (Direct Dial Dsomething? ="LD"?)
    # TF  Toll Free
    #     (toll free dst# should be sufficient to rate)
    # DAT Directory AssisTance
    #     (dst# 411 "area code" should be sufficient to rate)
    # DNS (Another sort of directory assistance?... only one record with
    #      "8195551212" in the dst#)
    'dcontext', #probably don't need... map to cdr_type?  calltypenum?

    # DURATION	Yes	Units = seconds
    'billsec', #need to trim .00 ?

    # AMOUNT CHARGED	No	Will use Freeside rating and description name
    sub { my( $cdr, $amount) = @_;
          $amount =~ s/^\$//;
          $cdr->upstream_price( $amount );
        },

  ],

);

1;

__END__

CHG TYPE        (unused)
ACCOUNT #       (unused)

DATE            startdate (+ CUST NO)
CUST NO         (startdate time)
                - Start of call (UNIX-style integer timestamp)

BTN            *src - Caller*ID number / Source number
ORIG CITY       channel - Channel used
TERM #         *dst - Destination extension
TERM CITY       dstchannel - Destination channel if appropriate
WTN            *charged_party - Service number to be billed
CODE           *accountcode - CDR account number to use: account

PROV/COUNTRY    (used to prefix TERM # w/ 1 or 011)

CALL TYPE       dcontext - Destination context
DURATION       *billsec - Total time call is up, in seconds
AMOUNT CHARGED *upstream_price - Wholesale price from upstream

