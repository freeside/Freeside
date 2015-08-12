package FS::cdr::earthlink;

use strict;
use vars qw( @ISA %info $date);
use Time::Local;
use FS::cdr qw(_cdr_min_parser_maker);
use Date::Parse;

@ISA = qw(FS::cdr);

my ($tmp_mday, $tmp_mon, $tmp_year);

%info = (
  'name'          => 'Earthlink',
  'weight'        => 120,
  'header'        => 1,
  'import_fields' => [

        skip(3),  			#Account number/ SERVICE LOC / BILL NUMBER 
        sub { my($cdr, $date) = @_;
        $date =~ /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/
        or die "unparseable date: $date";
        ($tmp_mon, $tmp_mday, $tmp_year) = ($1, $2, $3);
        }, 				#date 	    
	sub { my($cdr, $time) = @_;
        	  $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2}) (AM|PM)$/
            	  or die "unparsable time: $time"; #maybe we shouldn't die...
	  my $hour = $1;
          $hour += 12 if $4 eq 'PM' && $hour != 12;
          $hour = 0 if $4 eq 'AM' && $hour == 12;

	     my $dt = DateTime->new(
        	year    => $tmp_year,
        	month   => $tmp_mon,
        	day     => $tmp_mday,
        	hour    => $hour,
        	minute  => $2,
        	second  => $3,
        	time_zone => 'local',
      );
	      $cdr->set('startdate', $dt->epoch);

        },
        skip(1),                        #TollFreeNumber
	sub { my($cdr, $src) = @_;	
	$src =~ s/\D//g;
	$cdr->set('src', $src);
	},				#ORIG NUMBER
	skip(2),			#ORIG CITY/ORIGSTATE
	sub { my($cdr, $dst) = @_;
        $dst =~ s/\D//g;
        $cdr->set('dst', $dst);
        },				#TERM NUMBER
	skip(2),			#TERM CITY / TERM STATE
	_cdr_min_parser_maker, 		#MINUTES
	skip(1),			#AMOUNT
	'disposition',			#Call Type
	skip(1),			#Seq
	'accountcode',			#AcctCode
  ],
);

sub skip { map {''} (1..$_[0]) }

1;

