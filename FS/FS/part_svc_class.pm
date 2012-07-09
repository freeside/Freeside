package FS::part_svc_class;
use base qw( FS::class_Common );

use strict;
use FS::Record; # qw( qsearch qsearchs );

=head1 NAME

FS::part_svc_class - Object methods for part_svc_class records

=head1 SYNOPSIS

  use FS::part_svc_class;

  $record = new FS::part_svc_class \%hash;
  $record = new FS::part_svc_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_svc_class object represents a service class.  FS::part_svc_class
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item classnum

primary key

=item classname

classname

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new service class.  To add the service class to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_svc_class'; }

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

Checks all fields to make sure this is a valid service class.  If there is
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
    || $self->ut_enum('disabled', [ '', 'Y' ] )
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

