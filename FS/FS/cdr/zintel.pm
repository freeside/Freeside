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
    	'calldate',     #datetime
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

