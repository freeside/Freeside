package FS::agent_payment_gateway;
use base qw(FS::Record);

use strict;

=head1 NAME

FS::agent_payment_gateway - Object methods for agent_payment_gateway records

=head1 SYNOPSIS

  use FS::agent_payment_gateway;

  $record = new FS::agent_payment_gateway \%hash;
  $record = new FS::agent_payment_gateway { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::agent_payment_gateway object represents a payment gateway override for
a specific agent.  FS::agent_payment_gateway inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item agentgatewaynum - primary key

=item agentnum - 

=item gatewaynum - 

=item cardtype - 

=item taxclass - 

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new override.  To add the override to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'agent_payment_gateway'; }

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

Checks all fields to make sure this is a valid override.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('agentgatewaynum')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum')
    || $self->ut_foreign_key('gatewaynum', 'payment_gateway', 'gatewaynum' )
    || $self->ut_textn('cardtype')
    || $self->ut_textn('taxclass')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item payment_gateway

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::payment_gateway>, L<FS::agent>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

