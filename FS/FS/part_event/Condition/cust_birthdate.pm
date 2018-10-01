package FS::part_event::Condition::cust_birthdate;
use base qw( FS::part_event::Condition );
use strict;
use warnings;
use DateTime;

=head2 NAME

FS::part_event::Condition::cust_birthdate

=head1 DESCRIPTION

Billing event triggered by the time until the customer's next
birthday (cust_main.birthdate)

=cut

sub description {
  'Customer birthdate occurs within the given timeframe';
}

sub option_fields {
  (
    timeframe => {
      label => 'Timeframe',
      type   => 'freq',
      value  => '1m',
    }
  );
}

sub condition {
  my( $self, $object, %opt ) = @_;
  my $cust_main = $self->cust_main($object);

  my $birthdate = $cust_main->birthdate || return 0;

  my %timeframe;
  if ( $self->option('timeframe') =~ /(\d+)([mwdh])/ ) {
    my $k = {qw|m months w weeks d days h hours|}->{$2};
    $timeframe{ $k } = $1;
  } else {
    die "Unparsable timeframe given: ".$self->option('timeframe');
  }

  my $ck_dt = DateTime->from_epoch( epoch => $opt{time} );
  my $bd_dt = DateTime->from_epoch( epoch => $birthdate );

  # Find the birthday for this calendar year.  If customer birthday
  # has already passed this year, find the birthday for next year.
  my $next_bd_dt = DateTime->new(
    month => $bd_dt->month,
    day   => $bd_dt->day,
    year  => $ck_dt->year,
  );
  $next_bd_dt->add( years => 1 )
    if DateTime->compare( $next_bd_dt, $ck_dt ) == -1;

  # Does next birthday occur between now and specified duration?
  $ck_dt->add( %timeframe );
  DateTime->compare( $next_bd_dt, $ck_dt ) != 1 ? 1 : 0;
}

1;
