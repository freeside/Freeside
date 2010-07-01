package FS::rate_time_interval;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::rate_time_interval - Object methods for rate_time_interval records

=head1 SYNOPSIS

  use FS::rate_time_interval;

  $record = new FS::rate_time_interval \%hash;
  $record = new FS::rate_time_interval { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate_time_interval object represents an interval of clock time during 
the week, such as "Monday, 7 AM to 8 PM".  FS::rate_time_interval inherits 
from FS::Record.  The following fields are currently supported:

=over 4

=item intervalnum

primary key

=item stime

Start of the interval, in seconds from midnight on Sunday.

=item etime

End of the interval.

=item ratetimenum

A foreign key to an L<FS::rate_time> object representing the set of intervals 
to which this belongs.


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate_time_interval'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('intervalnum')
    || $self->ut_number('stime')
    || $self->ut_number('etime')
    || $self->ut_number('ratetimenum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rate_time

Returns the L<FS::rate_time> comprising this interval.

=cut

sub rate_time {
  my $self = shift;
  FS::rate_time->by_key($self->ratetimenum);
}

=item description

Returns two strings containing stime and etime, formatted 
"Day HH:MM:SS AM/PM".  Example: "Mon 5:00 AM".

=cut

my @days = qw(Sun Mon Tue Wed Thu Fri Sat);

sub description {
  my $self = shift;
  return map { 
            sprintf('%s %02d:%02d:%02d %s',
            $days[int($_/86400) % 7],
            int($_/3600) % 12,
            int($_/60) % 60,
            $_ % 60,
            (($_/3600) % 24 < 12) ? 'AM' : 'PM' )
       } ( $self->stime, $self->etime );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::rate_time>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

