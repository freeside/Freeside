package FS::cdr::ispphone;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr;
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'ISPPhone',
  'weight'        => 123,
  'header'        => 2,
  'import_fields' => [

	                 'src',	 # Form
		         'dst',  # To
     'upstream_dst_regionname',  # Country
                    'dcontext',  # Description
              	 
			sub { my ($cdr, $calldate) = @_;
                        	$cdr->set('calldate', $calldate);

			my $tmp_date;

 	                      if ($calldate =~ /^(\d{2})\/(\d{2})\/(\d{2})\s*(\d{1,2}):(\d{2})$/){

                	        $tmp_date = "$2/$1/$3 $4:$5:$6";
        	                        
			      } else { $tmp_date = $calldate; }
	
				$tmp_date = str2time($tmp_date);
                        	$cdr->set('startdate', $tmp_date);

                 	},       #DateTime

	                sub { my ($cdr, $duration) = @_;
				my ($min,$sec) = split(/:/, $duration);
				my $billsec = $sec + $min * 60;
				$cdr->set('billsec', $billsec);

		        },       #Charged time, min:sec

	      'upstream_price',  # Amount ( upstream price )
],

);

1;

