package FS::dsl_note;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::dsl_note - Object methods for dsl_note records

=head1 SYNOPSIS

  use FS::dsl_note;

  $record = new FS::dsl_note \%hash;
  $record = new FS::dsl_note { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::dsl_note object represents a DSL order note.  FS::dsl_note inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item notenum - primary key

=item svcnum - the DSL for this note, see L<FS::svc_dsl>

=item by - export-specific, e.g. note's author or ISP vs. telco/vendor

=item priority - export-specific, e.g. high priority or not; not used by most

=item date - note date

=item note - the note


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new note.  To add the note to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'dsl_note'; }

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

Checks all fields to make sure this is a valid note.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('notenum')
    || $self->ut_foreign_key('svcnum', 'svc_dsl', 'svcnum')
    || $self->ut_textn('by')
    || $self->ut_alphasn('priority')
    || $self->ut_numbern('date')
    || $self->ut_text('note')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

