package FS::part_router_field;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::router_field;
use FS::router;


@ISA = qw( FS::Record );

=head1 NAME

FS::part_router_field - Object methods for part_router_field records

=head1 SYNOPSIS

  use FS::part_router_field;

  $record = new FS::part_router_field \%hash;
  $record = new FS::part_router_field { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

A part_router_field represents an xfield definition for routers.  For more
information on xfields, see L<FS::part_sb_field>.

The following fields are supported:

=over 4

=item routerfieldpart - primary key (assigned automatically)

=item name - name of field

=item length

=item check_block

=item list_source

(See L<FS::part_sb_field> for details on these fields.)

=head1 METHODS

=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see "insert".

=cut

sub table { 'part_router_field'; }

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

Checks all fields to make sure this is a valid record.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;
  my $error = '';

  $self->name =~ /^([a-z0-9_\-\.]{1,15})$/i
    or return "Invalid field name for part_router_field";

  ''; #no error
}

=item list_values

Equivalent to "eval($part_router_field->list_source)".

=cut

sub list_values {
  my $self = shift;
  return () unless $self->list_source;
  my @opts = eval($self->list_source);
  if($@) { 
    warn $@;
    return ();
  } else { 
    return @opts;
  }
}

=back

=head1 VERSION

$Id: 

=head1 BUGS

Needless duplication of much of FS::part_sb_field, with the result that most of
the warnings about it apply here also.

=head1 SEE ALSO

FS::svc_broadband, FS::router, FS::router_field,  schema.html
from the base documentation.

=cut

1;

