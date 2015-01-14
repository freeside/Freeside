package FS::Getopt;

=head1 NAME

FS::Getopt - Getopt::Std for Freeside command line/cron scripts

=head1 SYNOPSIS

#!/usr/bin/perl

use FS::Getopt;
use FS::other_stuff;
our %opt;

getopts('AB');

print "Option A: $opt{A}
Option B: $opt{B}
Start date: $opt{start}
End date: $opt{end}
Freeside user: $opt{user}
Verbose mode: $DEBUG
";

=head1 DESCRIPTION

This module provides a wrapper around Getopt::Std::getopts() that 
automatically processes certain common command line options, and sets
up a convenient environment for writing a script.

Options will go into %main::opt, as if you had called getopts(..., \%opt).
All options recognized by the wrapper use (and will always use) lowercase 
letters as flags, so it's safe for a script to define its options as
capital letters.

Options recognized by the wrapper do not need to be included in the string
argument to getopts().

The following command line options are recognized:

=over 4

=item -v: Verbose mode. Sets $main::DEBUG.

=item -s: Start date. If provided, FS::Getopt will parse it as a date 
and set $opt{start} to the resulting Unix timestamp value. If parsing fails, 
displays an error and exits.

=item -e: End date. As for -s; sets $opt{end}.

=back

Calling getopts() also performs some additional setup: 

=over 4

=item Exports a function named &main::debug, which performs a warn() if 
$DEBUG has a true value, and if not, does nothing. This should be used to
output informational messages. (warn() is for warnings.)

=item Captures the first command line argument after any switches and 
sets $opt{user} to that value. If a value isn't provided, prints an error
and exits.

=item Loads L<FS::UID> and calls adminsuidsetup() to connect to the database.

=back

=cut

use strict;
use base 'Exporter';
use Getopt::Std ();
use FS::UID qw(adminsuidsetup);
use FS::Misc::DateTime qw(parse_datetime day_end);

our @EXPORT = qw( getopts debug );

sub getopts {
  my $optstring = shift;
  my %opt;
  $optstring .= 's:e:v';

  Getopt::Std::getopts($optstring, \%opt);

  $opt{user} = shift(@ARGV)
    or die "Freeside username required.\n";
  adminsuidsetup($opt{user})
    or die "Failed to connect as user '$opt{user}'.\n";

  # now we have config access
  if ( $opt{s} ) {
    $opt{start} = parse_datetime($opt{s})
      or die "Unable to parse start date '$opt{s}'.\n";
  }
  if ( $opt{e} ) {
    $opt{end} = parse_datetime($opt{e})
      or die "Unable to parse start date '$opt{e}'.\n";
    $opt{end} = day_end($opt{end});
  }
  if ( $opt{v} ) {
    $main::DEBUG ||= $opt{v};
  }

  %main::opt = %opt;
}

sub debug {
  warn(@_, "\n") if $main::DEBUG;
}

1;
