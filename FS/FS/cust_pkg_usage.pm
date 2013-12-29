package FS::cust_pkg_usage;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch ); #qsearchs );

=head1 NAME

FS::cust_pkg_usage - Object methods for cust_pkg_usage records

=head1 SYNOPSIS

  use FS::cust_pkg_usage;

  $record = new FS::cust_pkg_usage \%hash;
  $record = new FS::cust_pkg_usage { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_usage object represents a counter of remaining included
minutes on a voice-call package.  FS::cust_pkg_usage inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item pkgusagenum - primary key

=item pkgnum - the package (L<FS::cust_pkg>) containing the usage

=item pkgusagepart - the usage stock definition (L<FS::part_pkg_usage>).
This record in turn links to the call usage classes that are eligible to 
use these minutes.

=item minutes - the remaining minutes

=back

=head1 METHODS

=over 4

=item new HASHREF

# the new method can be inherited from FS::Record, if a table method is defined

=cut

sub table { 'cust_pkg_usage'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;
  my $error = $self->reset || $self->SUPER::delete;
}

=item reset

Remove all allocations of this usage to CDRs.

=cut

sub reset {
  my $self = shift;
  my $error = '';
  foreach (qsearch('cdr_cust_pkg_usage', { pkgusagenum => $self->pkgusagenum }))
  {
    $error ||= $_->delete;
  }
  $error;
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

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
    $self->ut_numbern('pkgusagenum')
    || $self->ut_foreign_key('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_numbern('minutes')
    || $self->ut_foreign_key('pkgusagepart', 'part_pkg_usage', 'pkgusagepart')
  ;
  return $error if $error;

  if ( $self->minutes eq '' ) {
    $self->set(minutes => $self->part_pkg_usage->minutes);
  }

  $self->SUPER::check;
}

=item cust_pkg

Return the L<FS::cust_pkg> linked to this record.

=item part_pkg_usage

Return the L<FS::part_pkg_usage> linked to this record.

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

