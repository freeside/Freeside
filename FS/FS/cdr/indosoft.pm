package FS::cdr::indosoft;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Indosoft Conference Bridge',
  'weight'        => 300,
  'header'        => 1,
  'type'          => 'csv',

  #listref of what to do with each field from the CDR, in order
  'import_fields' => [

    #cdr_id
    'uniqueid',

    #connect_time
    _cdr_date_parser_maker( ['startdate', 'answerdate' ] ),

    #disconnect_time
    _cdr_date_parser_maker('enddate'),

    #account_id
    'accountcode',

    #conference_id
    'userfield',

    #client_id
    'charged_party',

    #pin_used
    'dcontext',

    #channel
    'channel',

    #clid
    #'src',
    sub { my($cdr, $clid) = @_;
          $cdr->clid( $clid ); #because they called it 'clid' explicitly
          $cdr->src(  $clid );
        },

    #dnis
    'dst',

    #call_status
    'disposition',

    #conf_billing_code
    'lastapp', #arbitrary

    #participant_id
    'lastdata', #arbitrary

    #codr_id
    'dstchannel', #arbitrary

    #call_type
    'description',
    
  ],

);

1;

