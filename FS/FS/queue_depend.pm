package FS::queue_depend;
use base qw(FS::Record);

use strict;

=head1 NAME

FS::queue_depend - Object methods for queue_depend records

=head1 SYNOPSIS

  use FS::queue_depend;

  $record = new FS::queue_depend \%hash;
  $record = new FS::queue_depend { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::queue_depend object represents an job dependancy.  FS::queue_depend
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item dependnum - primary key

=item jobnum - source jobnum (see L<FS::queue>).

=item depend_jobnum - dependancy jobnum (see L<FS::queue>)

=back

The job specified by B<jobnum> depends on the job specified B<depend_jobnum> -
the B<jobnum> job will not be run until the B<depend_jobnum> job has completed
successfully (or manually removed).

=head1 METHODS

=over 4

=item new HASHREF

Creates a new dependancy.  To add the dependancy to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'queue_depend'; }

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

Checks all fields to make sure this is a valid dependancy.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('dependnum')
    || $self->ut_foreign_key('jobnum',        'queue', 'jobnum')
    || $self->ut_foreign_key('depend_jobnum', 'queue', 'jobnum')
    || $self->SUPER::check
  ;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::queue>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

