package FS::qual;

use strict;
use base qw( FS::option_Common );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::qual - Object methods for qual records

=head1 SYNOPSIS

  use FS::qual;

  $record = new FS::qual \%hash;
  $record = new FS::qual { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::qual object represents a qualification for service.  FS::qual inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item qualnum - primary key

=item contactnum - Contact (Prospect/Customer) - see L<FS::contact>

=item svctn - Service Telephone Number

=item svcdb - table used for this service.  See L<FS::svc_dsl> and
L<FS::svc_broadband>, among others.

=item vendor_qual_id - qualification id from vendor/telco

=item status - qualification status (e.g. (N)ew, (P)ending, (Q)ualifies)


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new qualification.  To add the qualification to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'qual'; }

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

Checks all fields to make sure this is a valid qualification.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('qualnum')
    || $self->ut_number('contactnum')
    || $self->ut_numbern('svctn')
    || $self->ut_alpha('svcdb')
    || $self->ut_textn('vendor_qual_id')
    || $self->ut_alpha('status')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

