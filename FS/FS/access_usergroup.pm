package FS::access_usergroup;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::access_user;
use FS::access_group;

@ISA = qw(FS::Record);

=head1 NAME

FS::access_usergroup - Object methods for access_usergroup records

=head1 SYNOPSIS

  use FS::access_usergroup;

  $record = new FS::access_usergroup \%hash;
  $record = new FS::access_usergroup { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_usergroup object represents an internal access user's membership
in a group.  FS::access_usergroup inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item usergroupnum - primary key

=item usernum - 

=item groupnum - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'access_usergroup'; }

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
    $self->ut_numbern('usergroupnum')
    || $self->ut_number('usernum')
    || $self->ut_number('groupnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item access_user

=cut

sub access_user {
  my $self = shift;
  qsearchs( 'access_user', { 'usernum' => $self->usernum } );
}

=item access_group

=cut

sub access_group {
  my $self = shift;
  qsearchs( 'access_group', { 'groupnum' => $self->groupnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

