package FS::cdr::amcom;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use DateTime;

my ($tmp_mday, $tmp_mon, $tmp_year);

%info = (
  'name'          => 'Amcom',
  'weight'        => 500,
  'header'        => 1,
  'type'          => 'csv',
  'sep_char'      => ',',
  'disabled'      => 0,

  #listref of what to do with each field from the CDR, in order
  'import_fields' => [

    sub {         # 1. Field Type (must be "DCR", yes, "DCR")
      my ($cdr, $field, $conf, $hashref) = @_;
      $hashref->{skiprow} = 1 unless $field eq 'DCR';
    },
    '',           # 2. BWGroupID (centrex group)
    '',           # 3. BWGroupNumber
    'uniqueid',   # 4. Record ID
    'dcontext',   # 5. Call Category (LOCAL, NATIONAL, FREECALL, MOBILE)
    sub {         # 6. Start Date (DDMMYYYY
      my ($cdr, $date) = @_;
      $date =~ /^(\d{2})(\d{2})(\d{4})$/
        or die "unparseable date: $date";
      ($tmp_mday, $tmp_mon, $tmp_year) = ($1, $2, $3);
    },
    sub {         # 7. Start Time (HHMMSS)
      my ($cdr, $time) = @_;
      $time =~ /^(\d{2})(\d{2})(\d{2})$/
        or die "unparseable time: $time";
      my $dt = DateTime->new(
        year    => $tmp_year,
        month   => $tmp_mon,
        day     => $tmp_mday,
        hour    => $1,
        minute  => $2,
        second  => $3,
      );
      $cdr->set('startdate', $dt->epoch);
    },
    sub {         # 8. Duration (seconds, 3 decimals)
      my ($cdr, $seconds) = @_;
      $cdr->set('duration', sprintf('%.0f', $seconds));
      $cdr->set('billsec', sprintf('%.0f', $seconds));
    },
    'src',        # 9. Calling Number
    'dst',        # 10. Called Number
    'upstream_src_regionname',  # 11. Calling Party Zone
    'upstream_dst_regionname',  # 12. Called Party Zone
    'upstream_price',           # 13. Call Cost
    '',                         # 14. Call Cost 2 (seems to be the same?)
    '',           # 15. Service Provider ID
    ('') x 4,     # 16-20. Reserved fields
  ],
);

1;
