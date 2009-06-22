package FS::cust_main_exemption;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;

=head1 NAME

FS::cust_main_exemption - Object methods for cust_main_exemption records

=head1 SYNOPSIS

  use FS::cust_main_exemption;

  $record = new FS::cust_main_exemption \%hash;
  $record = new FS::cust_main_exemption { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_main_exemption object represents a customer tax exemption from a
specific tax name (prefix).  FS::cust_main_exemption inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item exemptionnum

Primary key

=item custnum

Customer (see L<FS::cust_main>)

=item taxname

taxname


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_main_exemption'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('exemptionnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_text('taxname')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

