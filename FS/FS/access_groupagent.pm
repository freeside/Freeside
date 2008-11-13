package FS::access_groupagent;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::agent;
use FS::access_group;

@ISA = qw(FS::Record);

=head1 NAME

FS::access_groupagent - Object methods for access_groupagent records

=head1 SYNOPSIS

  use FS::access_groupagent;

  $record = new FS::access_groupagent \%hash;
  $record = new FS::access_groupagent { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::access_groupagent object represents an group reseller virtualization.  FS::access_groupagent inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item groupagentnum - primary key

=item groupnum - 

=item agentnum - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new group reseller virtualization.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'access_groupagent'; }

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

Checks all fields to make sure this is a valid group reseller virtualization.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('groupagentnum')
    || $self->ut_foreign_key('groupnum', 'access_group', 'groupnum')
    || $self->ut_foreign_key('agentnum', 'agent',        'agentnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item agent

Returns the associated FS::agent object.

=cut

sub agent {
  my $self = shift;
  qsearchs('agent', { 'agentnum' => $self->agentnum } );
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

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

