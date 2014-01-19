package FS::pbx_extension;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::pbx_extension - Object methods for pbx_extension records

=head1 SYNOPSIS

  use FS::pbx_extension;

  $record = new FS::pbx_extension \%hash;
  $record = new FS::pbx_extension { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pbx_extension object represents an PBX extension.  FS::pbx_extension
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item extensionnum

primary key

=item svcnum

svcnum

=item extension

extension

=item pin

pin

=item sip_password

sip_password

=item phone_name

phone_name


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new extension.  To add the extension to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'pbx_extension'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid extension.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('extensionnum')
    || $self->ut_foreign_key('svcnum', 'svc_pbx', 'svcnum')
    || $self->ut_number('extension')
    || $self->ut_numbern('pin')
    || $self->ut_textn('sip_password')
    || $self->ut_textn('phone_name')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_pbx>, L<FS::Record>

=cut

1;

