package FS::router_field;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs );
use FS::part_router_field;
use FS::router;


@ISA = qw( FS::Record );

=head1 NAME

FS::router_field - Object methods for router_field records

=head1 SYNOPSIS

  use FS::router_field;

  $record = new FS::router_field \%hash;
  $record = new FS::router_field { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

FS::router_field contains values of router xfields.  See FS::part_sb_field 
for details on the xfield mechanism.

=over 4

=item routerfieldpart - Type of router_field as defined by 
FS::part_router_field

=item routernum - The FS::router to which this value belongs.

=item value - The contents of the field.

=back

=head1 METHODS


=over 4

=item new HASHREF

Create a new record.  To add the record to the database, see "insert".

=cut

sub table { 'router_field'; }

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

  return "routernum must be defined" unless $self->routernum;
  return "routerfieldpart must be defined" unless $self->routerfieldpart;

  my $part_router_field = $self->part_router_field;
  $_ = $self->value;

  my $check_block = $part_router_field->check_block;
  if ($check_block) {
    $@ = '';
    my $error = (eval($check_block) or $@);
    return $error if $error;
    $self->setfield('value' => $_);
  }

  ''; #no error
}

=item part_router_field

Returns a reference to the FS:part_router_field that defines this 
FS::router_field

=cut

sub part_router_field {
  my $self = shift;

  return qsearchs('part_router_field', 
    { routerfieldpart => $self->routerfieldpart });
}

=item router

Returns a reference to the FS::router to which this FS::router_field 
belongs.

=cut

sub router {
  my $self = shift;

  return qsearchs('router', { routernum => $self->routernum });
}

=back

=head1 VERSION

$Id: 

=head1 BUGS

=head1 SEE ALSO

FS::svc_broadband, FS::router, FS::router_block, FS::router_field,  
schema.html from the base documentation.

=cut

1;

