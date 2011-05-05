package FS::cdr::freeside_description_default;

use strict;
use vars qw( @ISA %info $tmp_mon $tmp_mday $tmp_year );
use Time::Local;
use FS::cdr;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Freeside default with description field as destination',
  'weight'        => 25,
  'header'        => 1,
  'import_fields' => [
    'charged_party',     # Billed number
    'src',               # Caller

    # Date (YYYY/MM/DD)
    sub { my($cdr, $date) = @_;
          $date =~ /^(\d\d(\d\d)?)\/(\d{1,2})\/(\d{1,2})$/
            or die "unparsable date: $date"; #maybe we shouldn't die...
          ($tmp_mday, $tmp_mon, $tmp_year) = ( $4, $3-1, $1 );
        },

    # Time (HH:MM:SS (AM/PM))
    sub { my($cdr, $time) = @_;
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2}) (AM|PM)$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          my $hour = $1;
          $hour += 12 if $4 eq 'PM';
          $cdr->startdate(
            timelocal($3, $2, $hour ,$tmp_mday, $tmp_mon, $tmp_year)
          );
        },

    # Number
    sub {
        my($cdr, $number) = @_;
        $number =~ /(\d+)$/ 
            or die "unparsable number: $number"; #maybe we shouldn't die...
        $cdr->dst($1);
    },           

    'description',      # Destination (regionname)

    # Duration
    sub {
        my($cdr, $duration) = @_;
        $duration =~ /^(\d{1,2})m (\d{1,2})s$/
            or die "unparsable duration: $duration"; #maybe we shouldn't die...
        my $sec = $1*60 + $2;
        $cdr->duration($sec);
        $cdr->billsec($sec);
    },

    # Price
    sub {
        my($cdr, $amount) = @_;
        $amount =~ s/\$//g;
        $cdr->upstream_price($amount);
    }

  ],
);


