package FS::access_group;
use base qw( FS::m2m_Common FS::m2name_Common FS::Record );

use strict;
use Carp qw( croak );
use FS::Record qw( qsearch qsearchs );
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

=item grant_access_right RIGHTNAME

Grant the specified specified FS::access_right record to this group.
Return the FS::access_right record.

=cut

sub grant_access_right {
  my ( $self, $rightname ) = @_;

  croak "grant_access_right() requires \$rightname"
    unless $rightname;

  my $access_right = $self->access_right( $rightname );
  return $access_right if $access_right;

  $access_right = FS::access_right->new({
    righttype   => 'FS::access_group',
    rightobjnum => $self->groupnum,
    rightname   => $rightname,
  });
  if ( my $error = $access_right->insert ) {
    die "grant_access_right() error: $error";
  }

  $access_right;
}

=item revoke_access_right RIGHTNAME

Revoke the specified FS::access_right record from this group.

=cut

sub revoke_access_right {
  my ( $self, $rightname ) = @_;

  croak "revoke_access_right() requires \$rightname"
    unless $rightname;

  my $access_right = $self->access_right( $rightname )
    or return;

  if ( my $error = $access_right->delete ) {
    die "revoke_access_right() error: $error";
  }
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;
