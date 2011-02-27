package FS::torrus_srvderive;

use strict;
use base qw( FS::m2name_Common FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::torrus_srvderive_component;

=head1 NAME

FS::torrus_srvderive - Object methods for torrus_srvderive records

=head1 SYNOPSIS

  use FS::torrus_srvderive;

  $record = new FS::torrus_srvderive \%hash;
  $record = new FS::torrus_srvderive { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::torrus_srvderive object represents a Torrus virtual service ID.
FS::torrus_srvderive inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item derivenum

primary key

=item serviceid

serviceid

=item func

func


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'torrus_srvderive'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('derivenum')
    || $self->ut_text('serviceid')
    #|| $self->ut_text('func')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub torrus_srvderive_component {
  my $self = shift;
  qsearch('torrus_srvderive_component', { 'derivenum' => $self->derivenum } );
}

sub component_serviceids {
  my $self = shift;
  map $_->serviceid, $self->torrus_srvderive_component;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

