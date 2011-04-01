package FS::hardware_type;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::hardware_type - Object methods for hardware_type records

=head1 SYNOPSIS

  use FS::hardware_type;

  $record = new FS::hardware_type \%hash;
  $record = new FS::hardware_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::hardware_type object represents a device type (a model name or 
number) assignable as a hardware service (L<FS::svc_hardware)>).
FS::hardware_type inherits from FS::Record.  The following fields are 
currently supported:

=over 4

=item typenum - primary key

=item classnum - key to an L<FS::hardware_class> record defining the class 
to which this device type belongs.

=item model - descriptive model name or number

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'hardware_type'; }

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

Checks all fields to make sure this is a valid hardware type.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('typenum')
    || $self->ut_foreign_key('classnum', 'hardware_class', 'classnum')
    || $self->ut_text('model')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item hardware_class

Returns the L<FS::hardware_class> associated with this device.

=cut

sub hardware_class {
  my $self = shift;
  return qsearchs('hardware_class', { 'classnum' => $self->classnum });
}

=back

=head1 SEE ALSO

L<FS::svc_hardware>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

