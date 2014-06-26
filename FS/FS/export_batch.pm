package FS::export_batch;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::part_export;
use FS::export_batch_item;

=head1 NAME

FS::export_batch - Object methods for export_batch records

=head1 SYNOPSIS

  use FS::export_batch;

  $record = new FS::export_batch \%hash;
  $record = new FS::export_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_batch object represents a batch of records being processed
by an export.  This mechanism allows exports to process multiple pending
service changes at the end of day or some other scheduled time, rather 
than doing everything in realtime or near-realtime (via the job queue).

FS::export_batch inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item batchnum

primary key

=item exportnum

The L<FS::part_export> object that created this batch.

=item _date

The time the batch was created.

=item status

A status string.  Allowed values are "open" (for a newly created batch that
can receive additional items), "closed" (for a batch that is no longer 
allowed to receive items but is still being processed), "done" (for a batch
that is finished processing), and "failed" (if there has been an error 
exporting the batch).

=item statustext

Free-text field for any status information from the remote machine or whatever
else the export is doing.  If status is "failed" this MUST contain a value.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new batch.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'export_batch'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.  Don't ever do this.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid batch.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->set('status' => 'open') unless $self->get('status');
  $self->set('_date' => time) unless $self->get('_date');

  my $error = 
    $self->ut_numbern('batchnum')
    || $self->ut_number('exportnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_number('_date')
    || $self->ut_enum('status', [ qw(open closed done failed) ])
    || $self->ut_textn('statustext')
  ;
  return $error if $error;

  $self->SUPER::check;
}

# stubs, removed in 4.x

sub export_batch_item {
  my $self = shift;
  qsearch('export_batch_item', { batchnum => $self->batchnum });
}

sub part_export {
  my $self = shift;
  FS::part_export->by_key($self->exportnum);
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::part_export>, L<FS::export_batch_item>

=cut

1;

