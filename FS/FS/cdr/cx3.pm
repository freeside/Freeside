package FS::cdr::cx3;

use strict;
use vars qw( @ISA %info);
use FS::cdr;
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => '3CX',
  'weight'        => 120,
  'header'        => 1,
  'import_fields' => [


sub {                 
      	my ($cdr, $data, $conf, $param) = @_;
      	 	$param->{skiprow} = 1 unless $data =~ 'CallDetail'; # skip non-detail records
	},		# record type
	skip(2),	# unknown, callid ( not unique )
	'src',		# source
	'dst',		# destination
sub { my ($cdr, $calldate, $param) = @_;

	if ($calldate =~ /^(\d{2})\/(\d{2})\/(\d{4})\s*(\d{2}):(\d{2}):(\d{2})$/){

		$cdr->set('calldate', $calldate);
                my $tmp_date = "$2/$1/$3 $4:$5:$6";

                $tmp_date = str2time($tmp_date);
                $cdr->set('startdate', $tmp_date);
                }          
	},              #date
sub { my ($cdr, $duration) = @_;
               
	my ($hour,$min,$sec) = split(/:/,$duration);
	$sec += $min * 60;
	$sec += $hour * 60 * 60;
	$sec = sprintf ("%.0f", $sec);
	$cdr->set('billsec', $sec);

},			#duration
	skip(1),        # unknown
	'disposition',  # call status

  ],
);

sub skip { map {''} (1..$_[0]) }

1;
