package FS::agent_type;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch );

@ISA = qw( FS::Record );

=head1 NAME

FS::agent_type - Object methods for agent_type records

=head1 SYNOPSIS

  use FS::agent_type;

  $record = new FS::agent_type \%hash;
  $record = new FS::agent_type { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::agent_type object represents an agent type.  Every agent (see
L<FS::agent>) has an agent type.  Agent types define which packages (see
L<FS::part_pkg>) may be purchased by customers (see L<FS::cust_main>), via 
FS::type_pkgs records (see L<FS::type_pkgs>).  FS::agent_type inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item typenum - primary key (assigned automatically for new agent types)

=item atype - Text name of this agent type

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new agent type.  To add the agent type to the database, see
L<"insert">.

=cut

sub table { 'agent_type'; }

=item insert

Adds this agent type to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this agent type from the database.  Only agent types with no agents
can be deleted.  If there is an error, returns the error, otherwise returns
false.

=cut

sub delete {
  my $self = shift;

  return "Can't delete an agent_type with agents!"
    if qsearch( 'agent', { 'typenum' => $self->typenum } );

  $self->SUPER::delete;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid agent type.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('typenum')
  or $self->ut_text('atype');

}

=back

=head1 VERSION

$Id: agent_type.pm,v 1.2 1998-12-29 11:59:35 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::agent>, L<FS::type_pkgs>, L<FS::cust_main>,
L<FS::part_pkg>, schema.html from the base documentation.

=head1 HISTORY

Class for the different sets of allowable packages you can assign to an
agent.

ivan@sisd.com 97-nov-13

ut_ FS::Record methods
ivan@sisd.com 97-dec-10

Changed 'type' to 'atype' because Pg6.3 reserves the type word
	bmccane@maxbaud.net	98-apr-3

pod, added check in delete ivan@sisd.com 98-sep-21

$Log: agent_type.pm,v $
Revision 1.2  1998-12-29 11:59:35  ivan
mostly properly OO, some work still to be done with svc_ stuff


=cut

1;

