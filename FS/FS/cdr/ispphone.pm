package FS::cdr::ispphone;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw ( _cdr_date_parser_maker );
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'ISPPhone',
  'weight'        => 123,
  'header'        => 1,
  'import_fields' => [

                 'accountcode',  # Accountcode
	                sub { my ($cdr, $src) = @_;
				$src =~ s/^\s+//;
                                $cdr->set('src', $src);

                        },       # Form
		        sub { my ($cdr, $dst) = @_;
                                $dst =~ s/^\s+//;
                                $cdr->set('dst', $dst);

                        },       # To
		       skip(1),  # Country
     'upstream_dst_regionname',  # Description
_cdr_date_parser_maker('startdate'),  #DateTime

	                sub { my ($cdr, $duration) = @_;
				my ($min,$sec) = split(/:/, $duration);
				my $billsec = $sec + $min * 60;
				$cdr->set('billsec', $billsec);

		        },       #Charged time, min:sec

	      'upstream_price',  # Amount ( upstream price )
],

);

sub skip { map {''} (1..$_[0]) }

1;

