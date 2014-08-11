package FS::cdr::orcon;

use strict;
use vars qw( @ISA %info);
use FS::cdr;
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Orcon',
  'weight'        => 120,
  'header'        => 1,
  'import_fields' => [

	skip(1)      ,  #id
        skip(1)      ,  #billing period
        'accountcode',  #account number
        skip(2),        #username
                        #service id
        sub { my ($cdr, $calldate, $param) = @_;
        
         	$cdr->set('calldate', $calldate);

                if ($calldate =~ /^(\d{4})-(\d{2})-(\d{2})\s*(\d{2}):(\d{2}):(\d{2})$/){

                my $tmp_date = "$2/$3/$1 $4:$5:$6";

                $tmp_date = str2time($tmp_date);
                $cdr->set('startdate', $tmp_date);
	
		} else {

			$param->{skiprow} = 1
		}
                  },    #date
        skip(1),        #tariff region
        'src',          #originating number
        'dst',          #terminating number
        'duration',      #duration actual
        'billsec',	#duration billed
        skip(1),        #discount
        'upstream_price',#charge

  ],
);

sub skip { map {''} (1..$_[0]) }

1;

