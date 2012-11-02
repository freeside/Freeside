package FS::cdr::troop2;

use strict;
use base qw( FS::cdr );
use vars qw( %info $tmp_mon $tmp_mday $tmp_year $tmp_src_city $tmp_dst_city );
use Time::Local;
##use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

use Data::Dumper;

%info = (
  'name' => 'Troop',
  'weight' => 219,
  'header' => 1,
  'type'   => 'xls',

  'import_fields' => [

    'userfield', #account_num  (userfield?)

    # XXX false laziness w/bell_west.pm
    #call_date
    sub { my($cdr, $date) = @_;

          my $datetime = DateTime::Format::Excel->parse_datetime( $date );
          $tmp_mon  = $datetime->mon_0;
          $tmp_mday = $datetime->mday;
          $tmp_year = $datetime->year;
        },

    #call_time
    sub { my($cdr, $time) = @_;
          #my($sec, $min, $hour, $mday, $mon, $year)= localtime($cdr->startdate);

          #$sec = $time * 86400;
          my $sec = int( $time * 86400 + .5);

          #$cdr->startdate( timelocal($3, $2, $1 ,$mday, $mon, $year) );
          $cdr->startdate(
            timelocal(0, 0, 0, $tmp_mday, $tmp_mon, $tmp_year) + $sec
          );
        },

    'src', #orig_tn
    'dst', #term_tn

     #call_dur
    sub { my($cdr, $duration) = @_;
          $cdr->duration($duration);
          $cdr->billsec($duration);
        },

    'clid', #auth_code_ani (clid?)

    'accountcode', #account_code

    #ovs_type
    # OVS Type / Maybe / add "011" to international calls
    # N = DOM LD / normal
    # Z = INTL LD
    # O = INTL LD
    # others...?
    sub { my($cdr, $ovs) = @_;
          my $pre = ( $ovs =~ /^\s*[OZ]\s*$/i ) ? '011' : '1';
          $cdr->dst( $pre. $cdr->dst ) unless $cdr->dst =~ /^$pre/;
        },

    #orig_city
    sub { (my $cdr, $tmp_src_city) = @_; },

    #orig_prov_state
    sub { my($cdr, $state) = @_;
          $cdr->upstream_src_regionname("$tmp_src_city, $state");
        },

    #term_city
    sub { (my $cdr, $tmp_dst_city) = @_; },

    #term_prov_state
    sub { my($cdr, $state) = @_;
          $cdr->upstream_dst_regionname("$tmp_dst_city, $state");
        },

    #term_ovs
    '', #CANADA / UNITED STATES / BELL.  huh.  country or terminating provider?

    '', #cc_ind (what's this?)

    'upstream_price', #call_charge

    #important?
    '', #creation_date
    '', #creation_time

    #additional upstream pricing details we don't need?
    '', #net_charge
    '', #surcharge
    '', #gst
    '', #pst
    '', #hst

  ],

);

1;
