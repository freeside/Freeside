package FS::rt_field_charge;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::rt_field_charge - Object methods for rt_field_charge records

=head1 SYNOPSIS

  use FS::rt_field_charge;

  $record = new FS::rt_field_charge \%hash;
  $record = new FS::rt_field_charge { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rt_field_charge object represents an individual charge
that has been added to an invoice by a package with the rt_field price plan.
FS::rt_field_charge inherits from FS::Record.
The following fields are currently supported:

=over 4

=item rtfieldchargenum - primary key

=item pkgnum - cust_pkg that generated the charge

=item ticketid - RT ticket that generated the charge

=item rate - the rate per unit for the charge

=item units - quantity of units being charged

=item charge - the total amount charged

=item _date - billing date for the charge

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new object.  To add the object to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rt_field_charge'; }

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

Checks all fields to make sure this is a valid object.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('rtfieldchargenum')
    || $self->ut_foreign_key('pkgnum', 'cust_pkg', 'pkgnum' )
    || $self->ut_number('ticketid')
    || $self->ut_money('rate')
    || $self->ut_float('units')
    || $self->ut_money('charge')
    || $self->ut_number('_date')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS



=head1 SEE ALSO

L<FS::Record>

=cut

1;

