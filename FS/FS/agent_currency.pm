package FS::agent_currency;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );
use FS::agent;

=head1 NAME

FS::agent_currency - Object methods for agent_currency records

=head1 SYNOPSIS

  use FS::agent_currency;

  $record = new FS::agent_currency \%hash;
  $record = new FS::agent_currency { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::agent_currency object represents an agent's ability to sell
in a specific non-default currency.  FS::agent_currency inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item agentcurrencynum

primary key

=item agentnum

Agent (see L<FS::agent>)

=item currency

3 letter currency code

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'agent_currency'; }

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

  my $error = 
    $self->ut_numbern('agentcurrencynum')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum')
    || $self->ut_currency('currency')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::agent>

=cut

1;

