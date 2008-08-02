package FS::cdr::simple2;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw(_cdr_min_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Simple (Prerated)',
  'weight'        => 25,
  'header'        => 1,
  'import_fields' => [
    sub {},           #TEXT_TIME (redundant w/Time)
    sub {},           #Blank
    'src',            #Calling.

    #Date (YY/MM/DD)
    sub { my($cdr, $date) = @_;
          $date =~ /^(\d\d(\d\d)?)\/(\d{1,2})\/(\d{1,2})$/
            or die "unparsable date: $date"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal(0, 0, 0 ,$3, $2-1, $1) );
          ($tmp_mday, $tmp_mon, $tmp_year) = ( $3, $2-1, $1 );
        },

    #Time
    sub { my($cdr, $time) = @_;
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2})$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal($3, $2, $1 ,$mday, $mon, $year) );
          $cdr->startdate(
            timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year)
          );
        },

    'dst',            #Dest
    'userfield', #?   #DestinationDesc

    #Min
    _cdr_min_parser_maker, #( [qw( billsec duration)] ),
    
    sub {},           #Rate  XXX do something w/this, informationally???
    'upstream_price', #Total

    'accountcode',    #ServCode
    'description',    #Service_Type
  ],
);


