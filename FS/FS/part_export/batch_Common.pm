package FS::part_export::batch_Common;

use strict;
use base 'FS::part_export';
use FS::Record qw(qsearch qsearchs);
use FS::export_batch;
use FS::export_batch_item;
use Storable qw(nfreeze thaw);
use MIME::Base64 qw(encode_base64 decode_base64);

=head1 DESCRIPTION

FS::part_export::batch_Common should be inherited by any export that stores
pending service changes and processes them all at once.  It provides the 
external interface, and has an internal interface that the subclass must 
implement.

=head1 INTERFACE

ACTION in all of these methods is one of 'insert', 'delete', 'replace',
'suspend', 'unsuspend', 'pkg_change', or 'relocate'.

ARGUMENTS is the arguments to the export_* method:

- for insert, the new service

- for suspend, unsuspend, or delete, the service to act on

- for replace, the new service, followed by the old service

- for pkg_change, the service, followed by the new and old packages 
  (as L<FS::cust_pkg> objects)

- for relocate, the service, followed by the new location and old location
  (as L<FS::cust_location> objects)

=over 4

=item immediate ACTION, ARGUMENTS

This is called immediately from the export_* method, and does anything
that needs to happen right then, except for inserting the 
L<FS::export_batch_item> record.  Optional.  If it exists, it can return
a non-empty error string to cause the export to fail.

=item data ACTION, ARGUMENTS

This is called just before inserting the batch item, and returns a scalar
to store in the item's C<data> field.  If the export needs to remember 
anything about the service for the later batch-processing stage, it goes 
here.  Remember that if the service is being deleted, the export will need
to remember enough information to unprovision it when it's no longer in the 
database.

If this returns a reference, it will be frozen down with Base64-Storable.

=item process BATCH

This is called from freeside-daily, once for each batch still in the 'open'
or 'closed' state.  It's expected to do whatever needs to be done with the 
batch, and report failure via die().

=back

=head1 METHODS

=over 4

=cut

sub export_insert {
  my $self = shift;
  my $svc = shift;

  $self->immediate('insert', $svc) || $self->create_item('insert', $svc);
}

sub export_delete {
  my $self = shift;
  my $svc = shift;

  $self->immediate('delete', $svc) || $self->create_item('delete', $svc);
}

sub export_suspend {
  my $self = shift;
  my $svc = shift;

  $self->immediate('suspend', $svc) || $self->create_item('suspend', $svc);
}

sub export_unsuspend {
  my $self = shift;
  my $svc = shift;

  $self->immediate('unsuspend', $svc) || $self->create_item('unsuspend', $svc);
}

sub export_replace {
  my $self = shift;
  my $new = shift;
  my $old = shift;

  $self->immediate('replace', $new, $old) 
  || $self->create_item('replace', $new, $old)
}

sub export_relocate {
  my $self = shift;
  my $svc = shift;
  my $new_loc = shift;
  my $old_loc = shift;

  $self->immediate('relocate', $svc, $new_loc, $old_loc)
  || $self->create_item('relocate', $svc, $new_loc, $old_loc)
}

sub export_pkg_change {
  my $self = shift;
  my $svc = shift;
  my $new_pkg = shift;
  my $old_pkg = shift;

  $self->immediate('pkg_change', $svc, $new_pkg)
  || $self->create_item('pkg_change', $svc, $new_pkg)
}

=item create_item ACTION, ARGUMENTS

Creates and inserts the L<FS::export_batch_item> record for the action.

=cut

sub create_item {
  my $self = shift;
  my $action = shift;
  my $svc = shift;

  # get memo field
  my $data = $self->data($action, $svc, @_);
  my $frozen = '';
  if (ref $data) {
    $data = base64_encode(nfreeze($data));
    $frozen = 'Y';
  }
  my $batch_item = FS::export_batch_item->new({
      'svcnum'    => $svc->svcnum,
      'action'    => $action,
      'data'      => $data,
      'frozen'    => $frozen,
  });
  return $self->add_to_batch($batch_item);
}

sub immediate { # stub
  '';
}

=item add_to_batch ITEM

Actually inserts ITEM into the appropriate open batch.  All fields in ITEM
will be populated except for 'batchnum'.  By default, all items for a 
single export will go into the same batch, but subclass exports may override
this method.

=cut

sub add_to_batch {
  my $self = shift;
  my $batch_item = shift;
  $batch_item->set( 'batchnum', $self->open_batch->batchnum );

  $batch_item->insert;
}

=item open_batch

Returns the current open batch for this export.  If there isn't one yet,
this will create one.

=cut

sub open_batch {
  my $self = shift;
  my $batch = qsearchs('export_batch', { status => 'open',
                                         exportnum => $self->exportnum });
  if (!$batch) {
    $batch = FS::export_batch->new({
        status    => 'open',
        exportnum => $self->exportnum
    });
    my $error = $batch->insert;
    die $error if $error;
  }
  $batch;
}

=back

=cut

1;
