package FS::cdr::acmepacket;

=head1 NAME

FS:cdr::acmepacket - CDR import definition based on Acme Packet Net-Net 4000

=head1 DESCRIPTION

The Acme Packet NetNet 4000 S-CX6.4.0 generates an odd cdr log format:

 - Each row in the CSV may be in one of many various formats, some of
   them undocumented.
 - Columns are inconsistently enclosed with " characters
 - Quoted column values may, themselves, contain unescaped quote marks.
   This breaks Text::CSV (well technically the FORMAT is broken, not
   Text::CSV).
 - A single call can generate multiple CDR records.  The only records we're
   interested in are billable calls:
   - These are called "Stop Record CSV Placement" in Acme Packet documentation
   - These will always contain a "2" as the first column value
   - These rows may be 175 or 269 fields in length.  It's unclear if the
     undocumented 269 column rows are an intentional Acme Packet format, or
     a bug in their switch.  The extra columns are inserted at idx 115,
     and can safely be disregarded.

NOTE ON DATE PARSING:

  The Acme Packet manual doesn't describe it's date format in detail.  The sample
  we were given contains only records from December.  Dates are formatted like
  so: 15:54:56.868 PST DEC 18 2017

  I gave my best guess how they will format the month text in the parser
  FS::cdr::_cdr_date_parse().  If this format doesn't import records on a
  particular month, check there.

=cut

use strict;
use warnings;
use vars qw(%info);
use base qw(FS::cdr);
use FS::cdr qw(_cdr_date_parse);
use Text::CSV;

my $DEBUG = 0;

my $cbcsv = Text::CSV->new({binary => 1})
  or die "Error loading Text::CSV - ".Text::CSV->error_diag();

# Used to map source format into the contrived format created for import_fields
# $cdr_premap[ IMPORT_FIELDS_IDX ] = SOURCE_FORMAT_IDX
my @cdr_premap = (
  9,  # clid
  9,  # src
  10, # dst
  22, # channel
  21, # dstchannel
  26, # src_ip_addr
  28, # dst_ip_addr
  13, # startdate
  14, # answerdate
  15, # enddate
  12, # duration
  12, # billsec
  3,  # userfield
);

our %info = (
  name   => 'Acme Packet',
  weight => 600,
  header => 0,
  type   => 'csv',

  import_fields => [
    # freeside      # [idx] acmepacket
    'clid',         # 9  Calling-Station-Id
    'src',          # 9  Calling-Station-Id
    'dst',          # 10 Called-Station-Id
    'channel',      # 22 Acme-Session-Ingress-Realm
    'dstchannel',   # 23 Acme-Session-Egress-Realm
    'src_ip_addr',  # 26 Acme-Flow-In-Src-Adr_FS1_f
    'dst_ip_addr',  # 28 Acme-Flow-In-Dst-Addr_FS1_f
    'startdate',    # 13 h323-setup-time
    'answerdate',   # 14 h323-connect-time
    'enddate',      # 15 h323-disconnect-time
    'duration',     # 12 Acct-Session-Time
    'billsec',      # 12 Acct-Session-Time
    'userfield',    # 3 Acct-Session-Id
  ],

  row_callback => sub {
    my $line = shift;

    # Only process records whose first column contains a 2
    return undef unless $line =~ /^2\,/;

    # Replace unescaped quote characters within quote-enclosed text cols
    $line =~ s/(?<!\,)\"(?!\,)/\'/g;

    unless( $cbcsv->parse($line) ) {
      warn "Text::CSV Error parsing Acme Packet CDR: ".$cbcsv->error_diag();
      return undef;
    }

    my @row = $cbcsv->fields();
    if (@row == 269) {
      # Splice out the extra columns
      @row = (@row[0..114], @row[209..@row-1]);
    } elsif (@row != 175) {
      warn "Unknown row format parsing Acme Packet CDR";
      return undef;
    }

    my @out = map{ $row[$_] } @cdr_premap;

    if ($DEBUG) {
      warn "~~~~~~~~~~pre-processed~~~~~~~~~~~~~~~~ \n";
      warn "$_ $out[$_] \n" for (0..@out-1);
    }

    # answerdate, enddate, startdate
    for (7,8,9) {
      $out[$_] = _cdr_date_parse($out[$_]);
      if ($out[$_] =~ /\D/) {
        warn "Unparsable date in Acme Packet CDR: ($out[$_])";
        return undef;
      }
    }

    # clid, dst, src CDR field formatted as one of the following:
    #   'WIRELESS CALLER'<sip:12513001300@4.2.2.2:5060;user=phone>;tag=SDepng302
    #   <sip:12513001300@4.2.2.2:5060;user=phone>;tag=SDepng302

    # clid
    $out[0] = $out[0] =~ /^\'(.+)\'/ ? $1 : "";

    # src, dst
    # All of the sample data given shows sip connections.  In case the same
    # switch is hooked into another circuit type in the future, we'll just
    # tease out a length 7+ number not contained in the caller-id-text field
    for (1,2) {
      $out[$_] =~ s/^\'.+\'//g; # strip caller id label portion
      $out[$_] = $out[$_] =~ /(\d{7,})/ ? $1 : undef;
    }

    if ($DEBUG) {
      warn "~~~~~~~~~~post-processed~~~~~~~~~~~~~~~~ \n";
      warn "$_ $out[$_] \n" for (0..@out-1);
    }

    # I haven't seen commas in sample data text fields.  Extra caution,
    # mangle commas into periods as we pass back to importer
    join ',', map{ $_ =~ s/\,/\./g; $_ } @out;
  },
);

1;
