package FS::part_device;

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );

=head1 NAME

FS::part_device - Object methods for part_device records

=head1 SYNOPSIS

  use FS::part_device;

  $record = new FS::part_device \%hash;
  $record = new FS::part_device { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_device object represents a phone device definition. FS::part_device
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item devicepart

primary key

=item devicename

devicename


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_device'; }

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
    $self->ut_numbern('devicepart')
    || $self->ut_text('devicename')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub process_batch_import {
  my $job = shift;

  my $opt = { 'table'   => 'part_device',
              'params'  => [],
              'formats' => { 'default' => [ 'devicename' ] },
              'default_csv' => 1,
            };

  FS::Record::process_batch_import( $job, $opt, @_ );

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

