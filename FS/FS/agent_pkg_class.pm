package FS::agent_pkg_class;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );
use FS::agent;
use FS::pkg_class;

=head1 NAME

FS::agent_pkg_class - Object methods for agent_pkg_class records

=head1 SYNOPSIS

  use FS::agent_pkg_class;

  $record = new FS::agent_pkg_class \%hash;
  $record = new FS::agent_pkg_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::agent_pkg_class object represents a commission for a specific agent
and package class.  FS::agent_pkg_class inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item agentpkgclassnum

primary key

=item agentnum

agentnum

=item classnum

classnum

=item commission_percent

commission_percent


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'agent_pkg_class'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->commission_percent(0) unless length($self->commission_percent);

  my $error = 
    $self->ut_numbern('agentpkgclassnum')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum')
    || $self->ut_foreign_keyn('classnum', 'pkg_class', 'classnum')
    || $self->ut_float('commission_percent')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::agent>, L<FS::pkg_class>, L<FS::Record>.

=cut

1;

