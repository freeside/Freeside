package FS::inventory_item;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::inventory_class;

@ISA = qw(FS::Record);

=head1 NAME

FS::inventory_item - Object methods for inventory_item records

=head1 SYNOPSIS

  use FS::inventory_item;

  $record = new FS::inventory_item \%hash;
  $record = new FS::inventory_item { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::inventory_item object represents a specific piece of (real or virtual)
inventory, such as a specific DID or serial number.  FS::inventory_item
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item itemnum - primary key

=item classnum - Inventory class (see L<FS::inventory_class>)

=item item - Item identifier (unique within its inventory class)

=item svcnum - Customer servcie (see L<FS::cust_svc>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new item.  To add the item to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'inventory_item'; }

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

Checks all fields to make sure this is a valid item.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('itemnum')
    || $self->ut_foreign_key('classnum', 'inventory_class', 'classnum' )
    || $self->ut_text('item')
    || $self->ut_numbern('svcnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

