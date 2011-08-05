package FS::Misc::DateTime;

use base qw( Exporter );
use vars qw( @EXPORT_OK );
use POSIX;
use Carp;
use Date::Parse;
use DateTime::Format::Natural;
use FS::Conf;

@EXPORT_OK = qw( parse_datetime day_end );

=head1 NAME

FS::Misc::DateTime - Date and time subroutines

=head1 SYNOPSIS

use FS::Misc::DateTime qw( parse_datetime );

=head1 SUBROUTINES

=over 4

=item parse_datetime STRING

Parses a date (and possibly time) from the supplied string and returns
the date as an integer UNIX timestamp.

=cut

sub parse_datetime {
  my $string = shift;
  return '' unless $string =~ /\S/;

  my $conf = new FS::Conf;
  my $format = $conf->config('date_format') || '%m/%d/%Y';

  if ( $format eq '%d/%m/%Y' ) { #  =~ /\%d.*\%m/ ) {
    #$format =~ s/\%//g;
    my $parser = DateTime::Format::Natural->new( 'time_zone' => 'local',
                                                 #'format'=>'d/m/y',#lc($format)
                                               );
    $dt = $parser->parse_datetime($string);
    if ( $parser->success ) {
      return $dt->epoch;
    } else {
      #carp "WARNING: can't parse date: ". $parser->error;
      #return '';
      #huh, very common, we still need the "partially" (fully enough for our purposes) parsed date.
      $dt->epoch;
    }
  } else {
    return str2time($string);
  }
  
}

=item day_end TIME

If the next-bill-ignore-time configuration setting is turned off, just 
returns the passed-in value.

If the next-bill-ignore-time configuration setting is turned on, parses TIME
as an integer UNIX timestamp and returns a new timestamp with the same date but
23:59:59 for the time.

=cut

sub day_end {
    my $time = shift;

    my $conf = new FS::Conf;
    return $time unless $conf->exists('next-bill-ignore-time');

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
        localtime($time);
    mktime(59,59,23,$mday,$mon,$year,$wday,$yday,$isdst);
}

=back

=head1 BUGS

=cut

1;
