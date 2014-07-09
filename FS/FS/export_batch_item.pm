package FS::export_batch_item;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::export_batch_item - Object methods for export_batch_item records

=head1 SYNOPSIS

  use FS::export_batch_item;

  $record = new FS::export_batch_item \%hash;
  $record = new FS::export_batch_item { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_batch_item object represents a service change (insert, delete,
replace, suspend, unsuspend, or relocate) queued for processing by a 
batch-oriented export.

FS::export_batch_item inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item itemnum

primary key

=item batchnum

L<FS::export_batch> foreign key; the batch that this item belongs to.

=item svcnum

L<FS::cust_svc> foreign key; the service that is being exported.

=item action

One of 'insert', 'delete', 'replace', 'suspend', 'unsuspend', or 'relocate'.

=item data

A place for the export to store data relating to the service change.

=item frozen

A flag indicating that C<data> is a base64-Storable encoded object rather
than a simple string.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new batch item.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'export_batch_item'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('itemnum')
    || $self->ut_number('batchnum')
    || $self->ut_foreign_key('batchnum', 'export_batch', 'batchnum')
    || $self->ut_number('svcnum')
    || $self->ut_enum('action',
      [ qw(insert delete replace suspend unsuspend relocate) ]
    )
    || $self->ut_anything('data')
    || $self->ut_flag('frozen')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::export_batch>, L<FS::cust_svc>

=cut

1;

