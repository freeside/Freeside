package FS::sales;
use base qw( FS::Agent_Mixin FS::Record );

use strict;
use FS::agent;

=head1 NAME

FS::sales - Object methods for sales records

=head1 SYNOPSIS

  use FS::sales;

  $record = new FS::sales \%hash;
  $record = new FS::sales { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::sales object represents a sales person.  FS::sales inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item salesnum

primary key

=item agentnum

agentnum

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new sales person.  To add the sales person to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'sales'; }

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

Checks all fields to make sure this is a valid sales person.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('salesnum')
    || $self->ut_text('salesperson')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum')
    || $self->ut_enum('disabled', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

