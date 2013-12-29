package FS::part_export_option;
use base qw(FS::Record);

use strict;
use FS::Record qw( qsearchs ); #qw( qsearch qsearchs );

=head1 NAME

FS::part_export_option - Object methods for part_export_option records

=head1 SYNOPSIS

  use FS::part_export_option;

  $record = new FS::part_export_option \%hash;
  $record = new FS::part_export_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_export_option object represents an export option.
FS::part_export_option inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item optionnum - primary key

=item exportnum - export (see L<FS::part_export>)

=item optionname - option name

=item optionvalue - option value

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new export option.  To add the export option to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_export_option'; }

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

Checks all fields to make sure this is a valid export option.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('optionnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_alpha('optionname')
    || $self->ut_anything('optionvalue')
  ;
  return $error if $error;

  return "Unknown exportnum: ". $self->exportnum
    unless qsearchs('part_export', { 'exportnum' => $self->exportnum } );

  #check options & values?

  $self->SUPER::check;
}

=back

=head1 BUGS

Possibly.

=head1 SEE ALSO

L<FS::part_export>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

