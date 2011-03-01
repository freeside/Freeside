package FS::areacode;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::areacode - Object methods for areacode records

=head1 SYNOPSIS

  use FS::areacode;

  $record = new FS::areacode \%hash;
  $record = new FS::areacode { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::areacode object represents an example.  FS::areacode inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item code 

area code (primary key)

=item country

two-letter country code

=item state

two-letter state code, if appropriate

=item description

description (optional)


=back

=head1 METHODS

=over 4

=cut

sub table { 'areacode'; }

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

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_number('code')
    || $self->ut_text('country')
    || $self->ut_textn('state')
    || $self->ut_textn('description')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

locate CODE

Returns the country, state, and description for an area code.

=cut

sub locate {
  my $class = shift;
  my $code = shift;
  my $areacode = qsearchs('areacode', { code => $code })
    or return ();
  return ($areacode->country, $areacode->state, $areacode->description);
}

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

