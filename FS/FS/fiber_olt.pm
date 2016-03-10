package FS::fiber_olt;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::olt_site;

=head1 NAME

FS::fiber_olt - Object methods for fiber_olt records

=head1 SYNOPSIS

  use FS::fiber_olt;

  $record = new FS::fiber_olt \%hash;
  $record = new FS::fiber_olt { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::fiber_olt object represents an Optical Line Terminal that fiber
connections (L<FS::svc_fiber>) connect to.  FS::fiber_olt inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item oltnum - primary key

=item oltname - name of this device

=item serial - serial number

=item sitenum - the L<FS::olt_site> where this OLT is installed

=item disabled - set to 'Y' to make this OLT unavailable for new connections

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new fiber_olt record.  To add it to the database, see L<"insert">.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'fiber_olt'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

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
    $self->ut_numbern('oltnum')
    || $self->ut_text('oltname')
    || $self->ut_text('serial')
    || $self->ut_foreign_keyn('sitenum', 'olt_site', 'sitenum')
    || $self->ut_flag('disabled')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item site_description

Returns the OLT's site description.

=cut

sub site_description {
  my $self = shift;
  return '' if !$self->sitenum;
  my $olt_site = FS::olt_site->by_key($self->sitenum);
  return $olt_site->description;
}

=item description

Returns the OLT's site name and unit name.

=cut

sub description {
  my $self = shift;
  my $desc = $self->oltname;
  $desc = $self->site_description . '/' . $desc if $self->sitenum;
  return $desc;
}

=back

=head1 SEE ALSO

L<FS::svc_fiber>, L<FS::olt_site>, L<FS::Record>

=cut

1;

