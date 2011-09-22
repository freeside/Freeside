package FS::access_group;

use strict;
use base qw(FS::m2m_Common FS::m2name_Common FS::Record);
use FS::Record qw( qsearch qsearchs );
use FS::access_groupagent;
use FS::access_right;

=head1 NAME

FS::access_group - Object methods for access_group records

=head1 SYNOPSIS

  use FS::access_group;

  $record = new FS::access_group \%hash;
  $record = new FS::access_group { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_group object represents an access group.  FS::access_group inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item groupnum - primary key

=item groupname - Access group name

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new access group.  To add the access group to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'access_group'; }

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

Checks all fields to make sure this is a valid access group.  If there is
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
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item access_groupagent

Returns all associated FS::access_groupagent records.

=cut

sub access_groupagent {
  my $self = shift;
  qsearch('access_groupagent', { 'groupnum' => $self->groupnum } );
}

=item access_rights

Returns all associated FS::access_right records.

=cut

sub access_rights {
  my $self = shift;
  qsearch('access_right', { 'righttype'   => 'FS::access_group',
                            'rightobjnum' => $self->groupnum 
                          }
         );
}

=item access_right RIGHTNAME

Returns the specified FS::access_right record.  Can be used as a boolean, to
test if this group has the given RIGHTNAME.

=cut

sub access_right {
  my( $self, $name ) = @_;
  qsearchs('access_right', { 'righttype'   => 'FS::access_group',
                             'rightobjnum' => $self->groupnum,
                             'rightname'   => $name,
                           }
          );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

