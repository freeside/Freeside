package FS::export_svc;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::part_export;
use FS::part_svc;

@ISA = qw(FS::Record);

=head1 NAME

FS::export_svc - Object methods for export_svc records

=head1 SYNOPSIS

  use FS::export_svc;

  $record = new FS::export_svc \%hash;
  $record = new FS::export_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_svc object links a service definition (see L<FS::part_svc>) to
an export (see L<FS::part_export>).  FS::export_svc inherits from FS::Record.
The following fields are currently supported:

=over 4

=item exportsvcnum - primary key

=item exportnum - export (see L<FS::part_export>)

=item svcpart - service definition (see L<FS::part_svc>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'export_svc'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  $self->ut_numbern('exportsvcnum')
    || $self->ut_number('exportnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_number('svcpart')
    || $self->ut_foreign_key('svcpart', 'part_svc', 'svcpart')
    || $self->SUPER::check
  ;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_export>, L<FS::part_svc>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

