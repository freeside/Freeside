package FS::cdr::troop2;

use strict;
use base qw( FS::cdr );
use vars qw( %info $tmp_date $tmp_src_city $tmp_dst_city );
use Date::Parse;
#use Time::Local;
##use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name' => 'Troop',
  'weight' => 219,
  'header' => 1,
  'type'   => 'xls',

  'import_fields' => [

    'userfield', #account_num  (userfield?)

    #call_date
    sub { my($cdr, $date) = @_;
          #is this an excel date?  or just text?
          $tmp_date = $date;
        },

    #call_time
    sub { my($cdr, $time) = @_;
          #is this an excel time?  or just text?
          $cdr->startdate( str2time("$tmp_date $time") );
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
