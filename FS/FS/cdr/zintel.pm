package FS::cdr::zintel;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr qw(_cdr_date_parser_maker);
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Zintel',
  'weight'        => 123,
  'header'        => 1,
  'import_fields' => [

	'accountcode',	#customer
	'src',		#anumber
		 sub { my ($cdr, $dst) = @_; # Handling cosolidated local calls in the CDR formats

			my $src = $cdr->src;

			if ($dst =~ /^64\/U$/) {
			$cdr->set('dst', $src);
			} else {
			$cdr->set('dst', $dst);
			}
			}, #bnumber

                 sub { my ($cdr, $calldate) = @_;
                        $cdr->set('calldate', $calldate);

                        $calldate =~ /^(\d{2})\/(\d{2})\/(\d{4})\s*(\d{2}):(\d{2}):(\d{2})$/
                                or die "unparseable date: $calldate";
                        my $tmp_date = "$2/$1/$3 $4:$5:$6";

                        $tmp_date = str2time($tmp_date);
                        $cdr->set('startdate', $tmp_date);

                  },    #DateTime
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

