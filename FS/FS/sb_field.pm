package FS::sb_field;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::part_sb_field;

use UNIVERSAL qw( can );

@ISA = qw( FS::Record );

=head1 NAME

FS::sb_field - Object methods for sb_field records

=head1 SYNOPSIS

  use FS::sb_field;

  $record = new FS::sb_field \%hash;
  $record = new FS::sb_field { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

See L<FS::part_sb_field> for details on this table's mission in life.
FS::sb_field contains the actual values of the xfields defined in
part_sb_field.

The following fields are supported:

=over 4

=item sbfieldpart - Type of sb_field as defined by FS::part_sb_field

=item svcnum - The svc_broadband to which this value belongs.

=item value - The contents of the field.

=back

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'sb_field'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this record from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks the value against the check_block of the corresponding part_sb_field.
Returns whatever the check_block returned (unless the check_block dies, in 
which case check returns the die message).  Therefore, if the check_block 
wants to allow the value to be stored, it must return false.  See 
L<FS::part_sb_field> for details.

=cut

sub check {
  my $self = shift;

  return "svcnum must be defined" unless $self->svcnum;
  return "sbfieldpart must be defined" unless $self->sbfieldpart;

  my $part_sb_field = $self->part_sb_field;

  $_ = $self->value;

  my $check_block = $self->part_sb_field->check_block;
  if ($check_block) {
    $@ = '';
    my $error = (eval($check_block) or $@); # treat fatal errors as errors
    return $error if $error;
    $self->setfield('value' => $_);
  }

  ''; #no error
}

=item part_sb_field

Returns a reference to the FS::part_sb_field that defines this FS::sb_field.

=cut

sub part_sb_field {
  my $self = shift;

  return qsearchs('part_sb_field', { sbfieldpart => $self->sbfieldpart });
}

=back

=item svc_broadband

Returns a reference to the FS::svc_broadband to which this value is attached.
Nobody's ever going to use this function, but here it is anyway.

=cut

sub svc_broadband {
  my $self = shift;

  return qsearchs('svc_broadband', { svcnum => $self->svcnum });
}

=head1 VERSION

$Id: 

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_broadband>, schema.html
from the base documentation.

=cut

1;

