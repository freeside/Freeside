package FS::cdr::avaya_ipo;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr;
use Date::Parse;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Avaya IPO',
  'weight'        => 124,
  'header'        => 0,
  'import_fields' => [


         sub { my ($cdr, $info) = @_;
		my @data = split(/\s+/, $info);
		my $calldate = $data[4]. " ". $data[5];

          	$cdr->set('calldate', $calldate);
		$calldate =~ /^(\d{4})\/(\d{2})\/(\d{2})\s*(\d{2}):(\d{2}):(\d{2})$/
               		or die "unparseable date: $calldate";
                my $tmp_date = "$2/$3/$1 $4:$5:$6";
		$tmp_date = str2time($tmp_date);
                $cdr->set('startdate', $tmp_date);

              }, #DateTime

	 sub { my ($cdr, $duration) = @_;
		my ($hours,$min,$sec) = split(/:/, $duration);
		my $seconds += ($min * 60)+ ($hours * 60*60) + $sec;
                $cdr->set('billsec',$seconds); 
	     } , # Duration 00:00:00
        skip(1), # Ring time
   	sub { my ($cdr, $info) = @_;
		my ($src,$ip) = split(/@/,$info);
		$cdr->set('src',$src); 

	      }, # Callers number
        skip(2), # direction
                 # Called number
          'dst', # Dialed number
  'accountcode', # Accountcode
     'uniqueid', # call ID
        skip(5), # continuation
   'dstchannel', # Party2Device
        skip(9)  # AuthValid
                 # User Charged
                 # call Charge
                 # Currency
	         # Amount at Last User Change
                 # Call Units
                 # Units at Last User Change
                 # Cost per Unit
                 # Markup


],
);

sub skip { map {''} (1..$_[0]) }

1;

