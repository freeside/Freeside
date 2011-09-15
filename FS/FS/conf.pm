package FS::conf;

use strict;
use vars qw( @ISA );
use FS::Record;
use FS::Locales;

@ISA = qw(FS::Record);

=head1 NAME

FS::conf - Object methods for conf records

=head1 SYNOPSIS

  use FS::conf;

  $record = new FS::conf \%hash;
  $record = new FS::conf { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::conf object represents a configuration value.  FS::conf inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item confnum - primary key

=item agentnum - the agent to which this configuration value applies

=item name - the name of the configuration value

=item value - the configuration value


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new configuration value.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'conf'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid configuration value.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('confnum')
    || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
    || $self->ut_text('name')
    || $self->ut_anything('value')
    || $self->ut_enum('locale', [ '', FS::Locales->locales ])
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

