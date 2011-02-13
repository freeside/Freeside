package FS::did_order;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::did_order - Object methods for did_order records

=head1 SYNOPSIS

  use FS::did_order;

  $record = new FS::did_order \%hash;
  $record = new FS::did_order { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::did_order object represents a bulk DID order.  FS::did_order inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item ordernum

primary key

=item vendornum

vendornum

=item vendor_order_id

vendor_order_id

=item msa

msa

=item latanum

latanum

=item rate_center

rate_center

=item state

state

=item quantity

quantity

=item submitted

submitted

=item confirmed

confirmed

=item received

received


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new bulk DID order.  To add it to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'did_order'; }

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

Checks all fields to make sure this is a valid bulk DID order.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('ordernum')
    || $self->ut_foreign_key('vendornum', 'did_vendor', 'vendornum' )
    || $self->ut_text('vendor_order_id')
    || $self->ut_textn('msa')
    || $self->ut_foreign_keyn('latanum', 'lata', 'latanum')
    || $self->ut_textn('rate_center')
    || $self->ut_textn('state')
    || $self->ut_number('quantity')
    || $self->ut_number('submitted')
    || $self->ut_numbern('confirmed')
    || $self->ut_numbern('received')
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

