package FS::hardware_class;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::hardware_class - Object methods for hardware_class records

=head1 SYNOPSIS

  use FS::hardware_class;

  $record = new FS::hardware_class \%hash;
  $record = new FS::hardware_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::hardware_class object represents a class of hardware types which can 
be assigned to similar services (see L<FS::svc_hardware>).  FS::hardware_class 
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item classnum - primary key

=item classname - classname


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'hardware_class'; }

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

Checks all fields to make sure this is a valid hardware class.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('classnum')
    || $self->ut_text('classname')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item hardware_type

Returns all L<FS::hardware_type> objects belonging to this class.

=cut

sub hardware_type {
  my $self = shift;
  return qsearch('hardware_type', { 'classnum' => $self->classnum });
}

=back

=head1 SEE ALSO

L<FS::hardware_type>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

