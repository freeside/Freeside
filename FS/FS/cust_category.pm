package FS::cust_category;

use strict;
use base qw( FS::category_Common );
use FS::cust_class;

=head1 NAME

FS::cust_category - Object methods for cust_category records

=head1 SYNOPSIS

  use FS::cust_category;

  $record = new FS::cust_category \%hash;
  $record = new FS::cust_category { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_category object represents a customer category.  Every customer
class (see L<FS::cust_class>) has, optionally, a customer category.
FS::cust_category inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item categorynum

primary key

=item categoryname

Text name of this package category

=item weight

Weight

=item disabled

Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new customer category.  To add the customer category to the database,
see L<"insert">.

=cut

sub table { 'cust_category'; }

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

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_class>, L<FS::Record>

=cut

1;

