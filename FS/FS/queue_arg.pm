package FS::queue_arg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::queue_arg - Object methods for queue_arg records

=head1 SYNOPSIS

  use FS::queue_arg;

  $record = new FS::queue_arg \%hash;
  $record = new FS::queue_arg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::queue_arg object represents job argument.  FS::queue_arg inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item argnum - primary key

=item jobnum - see L<FS::queue>

=item frozen - argument is frozen with Storable

=item arg - argument

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new argument.  To add the argument to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'queue_arg'; }

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

Checks all fields to make sure this is a valid argument.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $error =
    $self->ut_numbern('argnum')
    || $self->ut_numbern('jobnum')
    || $self->ut_enum('frozen', [ '', 'Y' ])
    || $self->ut_anything('arg')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::queue>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

