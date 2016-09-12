package FS::part_event::Condition::holiday;

use strict;
use base qw( FS::part_event::Condition );
use DateTime;
use DateTime::Format::ICal;
use Tie::IxHash;

# rules lifted from DateTime::Event::Holiday::US,
# but their list is unordered, and contains duplicates and frivolous holidays
# it's better for future development for us to use our own hard-coded list,
# and the actual code beyond the list is just trivial use of DateTime::Format::ICal

tie my %holidays, 'Tie::IxHash', 
  'New Year\'s Day'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1' },   # January 1
  'Birthday of Martin Luther King, Jr.'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=1;BYDAY=3mo' },      # Third Monday in January
  'Washington\'s Birthday' 
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=2;BYDAY=3mo' },      # Third Monday in February
  'Memorial Day'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=5;BYDAY=-1mo' },     # Last Monday in May
  'Independence Day'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=4' },   # July 4
  'Labor Day'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=9;BYDAY=1mo' },      # First Monday in September
  'Columbus Day'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=2mo' },     # Second Monday in October
  'Veterans Day'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=11;BYMONTHDAY=11' }, # November 11
  'Thanksgiving Day'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=4th' },     # Fourth Thursday in November
  'Christmas'
    => { 'rule' => 'RRULE:FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25' }, # December 25
;

my $oneday = DateTime::Duration->new(days => 1);

sub description {
  "Do not run on holidays",
}

sub option_fields {
  (
    'holidays' => {
       label         => 'Do not run on',
       type          => 'checkbox-multiple',
       options       => [ keys %holidays ],
       option_labels => { map { $_ => $_ } keys %holidays },
       default_value => { map { $_ => 1  } keys %holidays }
    },
  );
}

sub condition {
  my( $self, $object, %opt ) = @_;
  my $today = DateTime->from_epoch(
    epoch     => $opt{'time'} || time,
    time_zone => 'local'
  )->truncate( to => 'day' );

  # if fri/mon, also check sat/sun respectively
  # federal holidays on weekends "move" to nearest weekday
  # eg Christmas 2016 is Mon Dec 26
  # we'll check both, so eg both Dec 25 & 26 are holidays in 2016
  my $offday;
  if ($today->day_of_week == 1) {
    $offday = $today->clone->subtract_duration($oneday);
  } elsif ($today->day_of_week == 5) {
    $offday = $today->clone->add_duration($oneday);
  }

  foreach my $holiday (keys %{$self->option('holidays')}) {
    $holidays{$holiday}{'set'} ||= 
      DateTime::Format::ICal->parse_recurrence(
        'recurrence' => $holidays{$holiday}{'rule'}
      );
    my $set = $holidays{$holiday}{'set'};
    return ''
      if $set->contains($today) or $offday && $set->contains($offday);
  }

  return 1;

}


# no condition_sql

1;
