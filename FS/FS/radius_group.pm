package FS::radius_group;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::radius_group - Object methods for radius_group records

=head1 SYNOPSIS

  use FS::radius_group;

  $record = new FS::radius_group \%hash;
  $record = new FS::radius_group { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::radius_group object represents a RADIUS group.  FS::radius_group inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item groupnum

primary key

=item groupname

groupname

=item description

description


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new RADIUS group.  To add the RADIUS group to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'radius_group'; }

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

Checks all fields to make sure this is a valid RADIUS group.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('groupnum')
    || $self->ut_text('groupname')
    || $self->ut_textn('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

This isn't export-specific (i.e. groups are globally unique, as opposed to being
unique per-export).

=head1 SEE ALSO

L<FS::radius_usergroup>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

