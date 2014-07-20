package FS::cdr::zintel_tollfree;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw(_cdr_date_parser_maker);
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Zintel Toll Free',
  'weight'        => 124,
  'header'        => 1,
  'import_fields' => [

	skip(1),	#customer
	'dst',		#line
	skip(1),	#answerpt
          	sub { my ($cdr, $calldate) = @_;
                        $cdr->set('calldate', $calldate);

                        $calldate =~ /^(\d{2})\/(\d{2})\/(\d{4})\s*(\d{2}):(\d{2}):(\d{2})$/
                                or die "unparseable date: $calldate";
                        my $tmp_date = "$2/$1/$3 $4:$5:$6";

                        $tmp_date = str2time($tmp_date);
                        $cdr->set('startdate', $tmp_date);

                  },    #DateTime
	'billsec',	#duration
	'src',          #caller    
	skip(1),	#status
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

