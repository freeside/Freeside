package FS::rate_time;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::rate_time_interval;

=head1 NAME

FS::rate_time - Object methods for rate_time records

=head1 SYNOPSIS

  use FS::rate_time;

  $record = new FS::rate_time \%hash;
  $record = new FS::rate_time { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate_time object represents a time period for selection of CDR billing 
rates.  FS::rate_time inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item ratetimenum

primary key

=item ratetimename

A label (like "Daytime" or "Weekend").

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate_time'; }

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
    $self->ut_numbern('ratetimenum')
    || $self->ut_text('ratetimename')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item intervals

Return the L<FS::rate_time_interval> objects included in this rating period.

=cut

sub intervals {
  my $self = shift;
  return qsearch({ table    => 'rate_time_interval', 
                   hashref  => { ratetimenum => $self->ratetimenum },
                   order_by => 'ORDER BY stime ASC',
  });
}

=item contains TIME

Return the L<FS::rate_time_interval> object that contains the specified 
time-of-week (in seconds from the start of Sunday).  The primary use of 
this is to test whether that time falls within this rating period.

=cut

sub contains {
  my $self = shift;
  my $weektime = shift;
  return qsearchs('rate_time_interval', { ratetimenum => $self->ratetimenum,
                                          stime => { op    => '<=', 
                                                     value => $weektime },
                                          etime => { op    => '>',
                                                     value => $weektime },
                                        } );
}

=item description

Returns a list of arrayrefs containing the starting and 
ending times of each interval in this period, in a readable
format.

=cut

sub description {
  my $self = shift;
  return map { [ $_->description ] } $self->intervals;
}


=back

=head1 BUGS

To be seen.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

