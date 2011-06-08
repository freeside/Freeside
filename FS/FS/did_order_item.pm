package FS::did_order_item;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::did_order_item - Object methods for did_order_item records

=head1 SYNOPSIS

  use FS::did_order_item;

  $record = new FS::did_order_item \%hash;
  $record = new FS::did_order_item { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::did_order_item object represents an item in a bulk DID order.
FS::did_order_item inherits from FS::Record.  
The following fields are currently supported:

=over 4

=item orderitemnum

primary key

=item ordernum

=item msanum - foreign key to msa table

=item npa

=item latanum - foreign key to lata table

=item ratecenternum - foreign key to rate_center table

=item state

=item quantity

=item custnum - foreign key to cust_main table, optional

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new DID order item.  To add it to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'did_order_item'; }

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

Checks all fields to make sure this is a valid DID order item.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('orderitemnum')
    || $self->ut_number('ordernum')
    || $self->ut_foreign_keyn('msanum', 'msa', 'msanum')
    || $self->ut_numbern('npa')
    || $self->ut_foreign_keyn('latanum', 'lata', 'latanum')
    || $self->ut_foreign_keyn('ratecenternum', 'rate_center', 'ratecenternum')
    || $self->ut_textn('state')
    || $self->ut_number('quantity')
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'custnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::did_order>, <FS::Record>, schema.html from the base documentation.

=cut

1;

