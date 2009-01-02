package FS::cdr::troop;

use strict;
use base qw( FS::cdr );
use vars qw( %info  $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
#use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Troop',
  'weight'        => 220,
  'header'        => 2,
  'type'          => 'xls',

  'import_fields' => [

    # CDR FIELD / REQUIRED / Notes

    # / No / CDR sequence number
    sub {},

    # WTN / Yes
    'charged_party',

    # Account Code / Yes / Account Code (security) and we need on invoice
    'accountcode',

    # DT / Yes / "DATE"   Excel
    # XXX false laziness w/bell_west.pm
    sub { my($cdr, $date) = @_;

          my $datetime = DateTime::Format::Excel->parse_datetime( $date );
          $tmp_mon  = $datetime->mon_0;
          $tmp_mday = $datetime->mday;
          $tmp_year = $datetime->year;
        },

    # Time / Yes / "TIME"  excel
    sub { my($cdr, $time) = @_;
          #my($sec, $min, $hour, $mday, $mon, $year)= localtime($cdr->startdate);

          #$sec = $time * 86400;
          my $sec = int( $time * 86400 + .5);

          #$cdr->startdate( timelocal($3, $2, $1 ,$mday, $mon, $year) );
          $cdr->startdate(
            timelocal(0, 0, 0, $tmp_mday, $tmp_mon, $tmp_year) + $sec
          );
        },


    # Dur. / Yes / Units = seconds
    'billsec',

    # OVS Type / Maybe / add "011" to international calls
    # N = DOM LD / normal
    # Z = INTL LD
    # O = INTL LD
    # others...?
    sub { my($cdr, $ovs) = @_;
          my $pre = ( $ovs =~ /^\s*[OZ]\s*$/i ) ? '011' : '1';
          $cdr->dst( $pre. $cdr->dst ) unless $cdr->dst =~ /^$pre/;
        },

    # Number / YES
    'src',

    # City / No
    'channel',

    # Prov/State / No / We will use your Freeside rating and description name
    sub { my($cdr, $state) = @_;
          $cdr->channel( $cdr->channel. ", $state" )
            if $state;
        },

    # Number / Yes
    'dst',

    # City / No
    'dstchannel',

    # Prov/State / No / We will use your Freeside rating and description name
    sub { my($cdr, $state) = @_;
          $cdr->dstchannel( $cdr->dstchannel. ", $state" )
            if $state;
        },

    # OVS / Maybe 
    # Would help to add "011" to international calls (if you are willing)
    # (using ovs above)
    sub { my($cdr, $ovs) = @_;
          my @ignore = ( 'BELL', 'CANADA', 'UNITED STATES', );
          $cdr->dstchannel( $cdr->dstchannel. ", $ovs" )
            if $ovs && ! grep { $ovs =~ /^\s*$_\s*$/ } @ignore;
        },

    # CC Ind. / No / Does show if Calling card but should not be required
    #'N' or 'E'
    sub {},

    # Call Charge / No / Bell billing info and is not required
    'upstream_price',

    # Account # / No / Bell billing info and is not required
    sub {},

    # Net Charge / No / Bell billing info and is not required
    sub {},

    # Surcharge / No / Taxes and is not required
    sub {},

    # GST / No / Taxes and is not required
    sub {},

    # PST / No / Taxes and is not required
    sub {},

    # HST / No / Taxes and is not required
    sub {},
    
  ],

);

1;

