package FS::cdr::callplus;
use base qw( FS::cdr );

use strict;
use vars qw( %info );
use FS::Record qw( qsearchs );
use Time::Local 'timelocal';

# Date format in the Date/Time col: "13/07/2016 2:40:32 p.m."
# d/m/y H:M:S, leading zeroes stripped, 12-hour with "a.m." or "p.m.".
# There are also separate d/m/y and 24-hour time columns, but parsing
# those separately is hard (DST issues).

%info = (
  'name'          => 'CallPlus',
  'weight'        => 610,
  'header'        => 1,
  'type'          => 'csv',
  'import_fields' => [
    'uniqueid',           # ID
    '',                   # Billing Group (charged_party?)
    'src',                # Origin Number
    'dst',                # Destination Number
    '',                   # Description (seems to be dest caller id?)
    '',                   # Status
    '',                   # Terminated
    '',                   # Date
    '',                   # Time
    sub {                 # Date/Time
      # this format overlaps one of the existing parser cases, so give it
      # its own special parser
      my ($cdr, $value) = @_;
      $value =~ m[^(\d{1,2})/(\d{1,2})/(\d{4}) (\d{1,2}):(\d{2}):(\d{2}) (a\.m\.|p\.m\.)$]
        or die "unparseable date: $value";
      my ($day, $mon, $year, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );
      $hour = $hour % 12;
      if ($7 eq 'p.m.') {
        $hour = 12;
      }
      $cdr->set('startdate',
                timelocal($sec, $min, $hour, $day, $mon-1, $year)
               );
    },
    sub {                 # Call Length (seconds)
      my ($cdr, $value) = @_;
      $cdr->set('duration', $value);
      $cdr->set('billsec', $value);
    },
    sub {                 # Call Cost (NZD)
      my ($cdr,$value) = @_;
      $value =~ s/^\$//;
      $cdr->upstream_price($value);
    },
    skip(2),              # Smartcode, Smartcode Description
    sub {                 # Type. "I" = international, which matters.
      my ($cdr, $value) = @_;
      if ($value eq 'I') {
        $cdr->set('dst', '+' . $cdr->dst);
      } # else leave it alone
    },
    '',                   # SubType
  ],
);

sub skip { map {''} (1..$_[0]) }

1;
