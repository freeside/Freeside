package FS::cust_bill_event;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::part_bill_event;

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_bill_event - Object methods for cust_bill_event records

=head1 SYNOPSIS

  use FS::cust_bill_event;

  $record = new FS::cust_bill_event \%hash;
  $record = new FS::cust_bill_event { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_event object represents an complete invoice event.
FS::cust_bill_event inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item eventnum - primary key

=item invnum - invoice (see L<FS::cust_bill>)

=item eventpart - event definition (see L<FS::part_bill_event>)

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new completed invoice event.  To add the compelted invoice event to
the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_bill_event'; }

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

Checks all fields to make sure this is a valid completed invoice event.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = $self->ut_numbern('eventnum')
    || $self->ut_number('invnum')
    || $self->ut_number('eventpart')
    || $self->ut_number('_date')
    || $self->ut_enum('status', [qw( done failed )]
    || $self->ut_textn('statustext');
  ;

  return "Unknown invnum"
    unless qsearchs( 'cust_bill' ,{ 'invnum' => $self->invnum } );

  return "Unknown eventpart"
    unless qsearchs( 'part_bill_event' ,{ 'eventpart' => $self->eventpart } );

  ''; #no error
}

=item part_bill_event

Returns the invoice event definition (see L<FS::part_bill_event>) for this
completed invoice event.

=cut

sub part_bill_event {
  my $self = shift;
  qsearchs( 'part_bill_event', { 'eventpart' => $self->eventpart } );
}

=back

=head1 BUGS

Far too early in the morning.

=head1 SEE ALSO

L<FS::part_bill_event>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

