package FS::svc_cable;
use base qw( FS::device_Common FS::svc_Common );

use strict;
use base qw( FS::Record );
use FS::Record; # qw( qsearch qsearchs );

=head1 NAME

FS::svc_cable - Object methods for svc_cable records

=head1 SYNOPSIS

  use FS::svc_cable;

  $record = new FS::svc_cable \%hash;
  $record = new FS::svc_cable { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_cable object represents a cable subscriber.  FS::svc_cable inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item svcnum

primary key

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'svc_cable'; }

sub table_info {
  {
    'name' => 'Cable Subscriber',
    #'name_plural' => '', #optional,
    #'longname_plural' => '', #optional
    'sorts' => [ 'svcnum', ], #, 'serviceid' ], # optional sort field (or arrayref of sort fields, main first)
    'display_weight' => 54,
    'cancel_weight'  => 70, #?  no deps, so
    'fields' => {
      'svcnum'     => 'Service',
      'identifier' => 'Identifier',
    },
  };
}

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
    $self->ut_numbern('svcnum')
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

