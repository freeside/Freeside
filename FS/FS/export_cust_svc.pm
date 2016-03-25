package FS::export_cust_svc;
use base qw(FS::Record);

use strict;
use FS::Record qw( qsearchs );

=head1 NAME

FS::export_cust_svc - Object methods for export_cust_svc records

=head1 SYNOPSIS

  use FS::export_cust_svc;

  $record = new FS::export_cust_svc \%hash;
  $record = new FS::export_cust_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::export_cust_svc object represents information unique
to a given part_export and cust_svc pair.
FS::export_cust_svc inherits from FS::Record.  
The following fields are currently supported:

=over 4

=item exportcustsvcnum - primary key

=item exportnum - export (see L<FS::part_export>)

=item svcnum - service (see L<FS::cust_svc>)

=item remoteid - id for accessing service on export remote system

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new export_cust_svc object.  To add the object to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'export_cust_svc'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;
  return "export_cust_svc for exportnum ".$self->exportnum.
         " svcnum ".$self->svcnum." already exists"
    if qsearchs('export_cust_svc',{ 'exportnum' => $self->exportnum,
                                    'svcnum'    => $self->svcnum });
  $self->SUPER::insert;
}

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

Checks all fields to make sure this is a valid export option.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('exportcustsvcnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum')
    || $self->ut_foreign_key('svcnum', 'cust_svc', 'svcnum')
    || $self->ut_text('remoteid')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Possibly.

=head1 SEE ALSO

L<FS::part_export>, L<FS::cust_svc>, L<FS::Record>

=cut

1;

