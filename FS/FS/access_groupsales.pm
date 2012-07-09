package FS::access_groupsales;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::access_groupsales - Object methods for access_groupsales records

=head1 SYNOPSIS

  use FS::access_groupsales;

  $record = new FS::access_groupsales \%hash;
  $record = new FS::access_groupsales { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_groupsales object represents an example.  FS::access_groupsales inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item groupsalesnum

primary key

=item groupnum

groupnum

=item salesnum

salesnum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'access_groupsales'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('groupsalesnum')
    || $self->ut_number('groupnum')
    || $self->ut_number('salesnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=item sales

Returns the associated FS::agent object.

=cut

sub sales {
  my $self = shift;
  qsearchs('sales', { 'salesnum' => $self->salesnum } );
}

=item access_group

Returns the associated FS::access_group object.

=cut

sub access_group {
  my $self = shift;
  qsearchs('access_group', { 'groupnum' => $self->groupnum } );
}

=back


=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

