package FS::nas;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::nas - Object methods for nas records

=head1 SYNOPSIS

  use FS::nas;

  $record = new FS::nas \%hash;
  $record = new FS::nas { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::nas object represents a RADIUS client.  FS::nas inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item nasnum

primary key

=item nasname

nasname

=item shortname

shortname

=item type

type

=item ports

ports

=item secret

secret

=item server

server

=item community

community

=item description

description


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new NAS.  To add the NAS to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'nas'; }

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

Checks all fields to make sure this is a valid NAS.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('nasnum')
    || $self->ut_text('nasname')
    || $self->ut_textn('shortname')
    || $self->ut_text('type')
    || $self->ut_numbern('ports')
    || $self->ut_text('secret')
    || $self->ut_textn('server')
    || $self->ut_textn('community')
    || $self->ut_text('description')
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

