package FS::UI::bytecount;

use strict;
use vars qw($DEBUG $me);
use FS::Conf;
use Number::Format 1.50;

$DEBUG = 0;
$me = '[FS::UID::bytecount]';

=head1 NAME

FS::UI::bytecount - Subroutines for parsing and displaying byte counters

=head1 SYNOPSIS

  use FS::UI::bytecount;

=head1 SUBROUTINES

=over 4

=item bytecount_unexact COUNT

Returns a two decimal place value for COUNT followed by bytes, Kbytes, Mbytes,
or GBytes as appropriate.

=cut

sub bytecount_unexact {
  my $bc = shift;
  return("$bc bytes")
    if ($bc < 1000);
  return(sprintf("%.2f Kbytes", $bc/1024))
    if ($bc < 1048576);
  return(sprintf("%.2f Mbytes", $bc/1048576))
    if ($bc < 1073741824);
  return(sprintf("%.2f Gbytes", $bc/1073741824));
}

=item parse_bytecount AMOUNT

Accepts a number (digits and a decimal point) possibly followed by k, m, g, or
t (and an optional 'b') in either case.  Returns a pure number representing
the input or the input itself if unparsable.  Discards commas as noise.

=cut

sub parse_bytecount {
  my $bc = shift;
  return $bc if (($bc =~ tr/.//) > 1);
  $bc =~ /^\s*([,\d.]*)\s*([kKmMgGtT]?)[bB]?\s*$/ or return $bc;
  my $base = $1;
  $base =~ tr/,//d;
  return $bc unless length $base;
  my $exponent = index ' kmgt', lc($2);
  return $bc if ($exponent < 0 && $2);
  $exponent = 0 if ($exponent < 0);
  return int($base * 1024 ** $exponent);  #bytecounts are integer values
}

=item display_bytecount AMOUNT

Converts a pure number to a value followed possibly followed by k, m, g, or
t via Number::Format

=cut

sub display_bytecount {
  my $bc = shift;
  return $bc unless ($bc =~ /^(\d+)$/);
  my $conf = new FS::Conf;
  my $f = new Number::Format;
  my $precision = ( $conf->exists('datavolume-significantdigits') &&
                    $conf->config('datavolume-significantdigits') =~ /^\s*\d+\s*$/ )
                ? $conf->config('datavolume-significantdigits')
                : 3;
  my $unit = $conf->exists('datavolume-forcemegabytes') ? 'M' : 'A';

  return $f->format_bytes($bc, precision => $precision, unit => $unit);
}

=back

=head1 BUGS

Fly

=head1 SEE ALSO

L<Number::Format>

=cut

1;

