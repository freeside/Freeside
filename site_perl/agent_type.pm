package FS::agent_type;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(qsearch fields);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

=head1 NAME

FS::agent_type - Object methods for agent_type records

=head1 SYNOPSIS

  use FS::agent_type;

  $record = create FS::agent_type \%hash;
  $record = create FS::agent_type { 'column' => 'value' };

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

=item create HASHREF

Creates a new agent type.  To add the agent type to the database, see
L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('agent_type')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('agent_type',$hashref);

}

=item insert

Adds this agent type to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Deletes this agent type from the database.  Only agent types with no agents
can be deleted.  If there is an error, returns the error, otherwise returns
false.

=cut

sub delete {
  my($self)=@_;
  return "Can't delete an agent_type with agents!"
    if qsearch('agent',{'typenum' => $self->typenum});
  $self->del;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a agent_type record!" unless $old->table eq "agent_type";
  return "Can't change typenum!"   
    unless $old->getfield('typenum') eq $new->getfield('typenum');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid agent type.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my($self)=@_;
  return "Not a agent_type record!" unless $self->table eq "agent_type";

  $self->ut_numbern('typenum')
  or $self->ut_text('atype');

}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

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

=cut

1;

