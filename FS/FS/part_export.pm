package FS::part_export;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::part_svc;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_export - Object methods for part_export records

=head1 SYNOPSIS

  use FS::part_export;

  $record = new FS::part_export \%hash;
  $record = new FS::part_export { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_export object represents an export of Freeside data to an external
provisioning system.  FS::part_export inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item eventpart - primary key

=item svcpart - Service definition (see L<FS::part_svc>) to which this export applies

=item machine - Machine name 

=item exporttype - Export type

=item nodomain - blank or "Y" : usernames are exported to this service with no domain

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new export.  To add the export to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_export'; }

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

Checks all fields to make sure this is a valid export.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $error = 
    $self->ut_numbern('exportnum')
    || $self->ut_number('svcpart')
    || $self->ut_alpha('exporttype')
  ;
  return $error if $error;

  return "Unknown svcpart: ". $self->svcpart
    unless qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );

  $self->machine =~ /^([\w\-\.]*)$/
    or return "Illegal machine: ". $self->machine;
  $self->machine($1);

  $self->nodomain =~ /^(Y?)$/ or return "Illegal nodomain: ". $self->nodomain;
  $self->nodomain($1);

  #check exporttype?

  ''; #no error
}

=back

=head1 BUGS

Probably.

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::part_svc>, L<FS::svc_acct>, L<FS::svc_domain>,
L<FS::svc_forward>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

