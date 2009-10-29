package FS::cust_class;

use strict;
use base qw( FS::class_Common );
use FS::cust_main;
use FS::cust_category;

=head1 NAME

FS::cust_class - Object methods for cust_class records

=head1 SYNOPSIS

  use FS::cust_class;

  $record = new FS::cust_class \%hash;
  $record = new FS::cust_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pkg_class object represents an customer class.  Every customer (see
L<FS::cust_main>) has, optionally, a customer class. FS::cust_class inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item classnum

primary key

=item classname

Text name of this customer class

=item categorynum

Number of associated cust_category (see L<FS::cust_category>)

=item disabled

Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new customer class.  To add the customer class to the database, see
L<"insert">.

=cut

sub table { 'cust_class'; }
sub _target_table { 'cust_main'; }

=item insert

Adds this customer class to the database.  If there is an error, returns the
error, otherwise returns false.

=item delete

Delete this customer class from the database.  Only customer classes with no
associated customers can be deleted.  If there is an error, returns
the error, otherwise returns false.

=item replace [ OLD_RECORD ]

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid customer class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=item cust_category

=item category

Returns the cust_category record associated with this class, or false if there
is none.

=cut

sub cust_category {
  my $self = shift;
  $self->category;
}

=item categoryname

Returns the category name associated with this class, or false if there
is none.

=cut

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;
