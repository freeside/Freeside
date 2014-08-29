package FS::cdr::netsapiens;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'NetSapiens',
  'weight'        => 160,
  'header'        => 1,     #0 default, set to 1 to ignore the first line, or
                            # to higher numbers to ignore that number of lines
  'type'          => 'csv',
  'sep_char'      => ',',   #for csv, defaults to ,
  'disabled'      => 0,     #0 default, set to 1 to disable

  'import_fields' => [

    sub { my ($cdr, $direction) = @_;
          if ($direction =~ /^t/) { # 'origination'
            # leave src and dst as they are
          } elsif ($direction =~ /^o/) {
            my ($local, $remote) = ($cdr->src, $cdr->dst);
            $cdr->set('dst', $local);
            $cdr->set('src', $remote);
          }
        },
    '', #Domain
    '', #user
    'src', #local party (src/dst, based on direction)
    _cdr_date_parser_maker('startdate'),
    _cdr_date_parser_maker('answerdate'),
    sub { my ($cdr, $duration) = @_;
          $cdr->set('duration', $duration);
          $cdr->set('billsec',  $duration);
          $cdr->set('enddate',  $duration + $cdr->answerdate)
            if $cdr->answerdate;
        },
    'dst', #remote party
    sub { my ($cdr, $dialednum) = @_;
        $cdr->set('dst',$dialednum) if $dialednum =~ /^(\+?1)?8(8|([02-7])\3)/;
        }, #dialed number
    'uniqueid', #CallID (timestamp + '-' +  32 char hex string)
    '',
    '',
    'disposition',
  ],

);

1;
