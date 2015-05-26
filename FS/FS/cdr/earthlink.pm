package FS::cdr::earthlink;

use strict;
use vars qw( @ISA %info $date);
use Time::Local;
use FS::cdr qw(_cdr_date_parser_maker _cdr_min_parser_maker);
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Earthlink',
  'weight'        => 120,
  'header'        => 1,
  'import_fields' => [

	'accountcode',			#Account number
              skip(2),  		#SERVICE LOC / BILL NUMBER 
	sub { my($cdr, $date) = @_;  
	$date;	
	}, 				#date 
	sub { my($cdr, $time) = @_;

	my $datetime = $date. " ". $time;
	$cdr->set('startdate', $datetime );
        },              		#time
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
  ],
);

sub skip { map {''} (1..$_[0]) }

1;

