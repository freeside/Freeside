package FS::olt_site;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::olt_site - Object methods for olt_site records

=head1 SYNOPSIS

  use FS::olt_site;

  $record = new FS::olt_site \%hash;
  $record = new FS::olt_site { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::olt_site object represents a central office housing Optical Line
Terminals (L<FS::fiber_olt>). FS::olt_site inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item sitenum - primary key

=item market - market designator, indicating the general area the site serves

=item site - site designator

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

=cut

sub table { 'olt_site'; }

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
    $self->ut_numbern('sitenum')
    || $self->ut_text('market')
    || $self->ut_text('site')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub description {
  my $self = shift;
  return $self->market . '/' . $self->site;
}

=back

=head1 SEE ALSO

L<FS::Record>, L<FS::fiber_olt>

=cut

1;

