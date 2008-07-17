package FS::cdr::simple;

use vars qw(@ISA %info);
use FS::cdr;

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'Simple',
  'weight'        => 20,
  'header'        => 1,
  'import_fields' => [

    # Date
    sub { my($cdr, $date) = @_;
          $date =~ /^(\d{1,2})\/(\d{1,2})\/(\d\d(\d\d)?)$/
            or die "unparsable date: $date"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal(0, 0, 0 ,$2, $1-1, $3) );
          ($tmp_mday, $tmp_mon, $tmp_year) = ( $2, $1-1, $3 );
        },

    # Time
    sub { my($cdr, $time) = @_;
          #my($sec, $min, $hour, $mday, $mon, $year)= localtime($cdr->startdate);
          $time =~ /^(\d{1,2}):(\d{1,2}):(\d{1,2})$/
            or die "unparsable time: $time"; #maybe we shouldn't die...
          #$cdr->startdate( timelocal($3, $2, $1 ,$mday, $mon, $year) );
          $cdr->startdate(
            timelocal($3, $2, $1 ,$tmp_mday, $tmp_mon, $tmp_year)
          );
        },

    # Source_Number
    'src',

    # Terminating_Number
    'dst',

    # Duration
    sub { my($cdr, $min) = @_;
          my $sec = sprintf('%.0f', $min * 60 );
          $cdr->billsec(  $sec );
          $cdr->duration( $sec );
        },

  ],
);

1;
