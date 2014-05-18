package FS::cdr::zintel;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw(_cdr_date_parser_maker);

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Zintel',
  'weight'        => 123,
  'header'        => 1,
  'import_fields' => [

	'accountcode',	#customer
	'src',		#anumber
	'dst',		#bnumber
	sub { # OriginatingDate and OriginatingTime, two fields in the spec
      		my ($cdr, $date) = @_;
      		$date =~ /^(\d{2})\/(\d{2})\/(\d{4})\s*(\d{2}):(\d{2}):(\d{2})$/
        	or die "unparseable date: $date";
		my $tmp_date = "$2/$1/$3 $4:$5:$6";      		
		$cdr->calldate($tmp_date);
    	     },#datetime

	'billsec',	#duration
	skip(3),	#calltype
			#status
			#product
	'upstream_price',#sellprice
	skip(1),	#fromregion
	'upstream_src_regionname',		#fromarea
	skip(2),	#fromc2city
			#toregion
	'upstream_dst_regionname',		#toarea
	skip(2),	#toc2city
			#group_label
  ],
);

sub skip { map {''} (1..$_[0]) }

1;

