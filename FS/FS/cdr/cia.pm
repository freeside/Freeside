package FS::cdr::cia;

use strict;
use vars qw( @ISA %info $date $tmp_mday $tmp_mon $tmp_year);
use FS::cdr qw(_cdr_date_parser_maker);
use Time::Local;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Client Instant Access',
  'weight'        => 510,
  'header'        => 1,
  'type'          => 'csv',
  'sep_char'      => "|",
  'import_fields' => [
    'accountcode',
    skip(2),          # First and last name

    sub { my($cdr, $date) = @_;
          $date =~ /^(\d{1,2})\/(\d{1,2})\/(\d\d(\d\d)?)$/
            or die "unparsable date: $date"; #maybe we shouldn't die...
          ($tmp_mday, $tmp_mon, $tmp_year) = ( $2, $1-1, $3 );
        }, #Date

    sub { my($cdr, $time) = @_;
          #my($sec, $min, $hour, $mday, $mon, $year)= localtime($cdr->startdate);
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2})$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          $cdr->startdate( timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year));
          $cdr->answerdate( timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year));
         
        }, # Start time

    sub { my($cdr, $time) = @_;
          #my($sec, $min, $hour, $mday, $mon, $year)= localtime($cdr->startdate);
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2})$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal($3, $2, $1 ,$mday, $mon, $year) );
          $cdr->enddate(
            timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year) ); 
        }, # End time

    'disposition',    # Disposition
    'dst',            # PhoneNumber
    skip(3),          # Extension, Service Type, Filler
    'src',            # ClientContactID
    ],

);

sub skip { map {''} (1..$_[0]) }

1;
