package FS::cdr::cx3;

use strict;
use vars qw( @ISA %info);
use FS::cdr;
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => '3CX',
  'weight'        => 120,
  'import_fields' => [


	sub {                 
      		my ($cdr, $data, $conf, $param) = @_;
      	 	$param->{skiprow} = 1 unless $data =~ /Call\s/ ; # skip non-detail records
	},		# record type
	skip(1),	# unknown, callid ( not unique )
	sub { my ($cdr, $duration) = @_;
	
		my ($hour,$min,$sec) = split(/:/,$duration);
		$sec = sprintf ("%.0f", $sec);
		$sec += $min * 60;
		$sec += $hour * 60 * 60;
		$cdr->set('billsec', $sec);

	},		# duration
	skip(1),		
	sub { my ($cdr, $calldate, $param) = @_;

		$cdr->set('calldate', $calldate);
	},              #date
	skip(4),          
	'accountcode',  # AccountCode
	skip(6),		
	'src',		# source
	'dst',		# destination

  ],
);

sub skip { map {''} (1..$_[0]) }

1;
