package FS::part_pkg_usage_class;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::part_pkg_usage_class - Object methods for part_pkg_usage_class records

=head1 SYNOPSIS

  use FS::part_pkg_usage_class;

  $record = new FS::part_pkg_usage_class \%hash;
  $record = new FS::part_pkg_usage_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_usage_class object is a link between a package usage stock
(L<FS::part_pkg_usage>) and a voice usage class (L<FS::usage_class)>.
FS::part_pkg_usage_class inherits from FS::Record.  The following fields 
are currently supported:

=over 4

=item num - primary key

=item pkgusagepart - L<FS::part_pkg_usage> key

=item classnum - L<FS::usage_class> key.  Set to null to allow this stock
to be used for calls that have no usage class.  To avoid confusion, you
should only do this if you don't use usage classes on your system.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_pkg_usage_class'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('num')
    || $self->ut_foreign_key('pkgusagepart', 'part_pkg_usage', 'pkgusagepart')
    || $self->ut_foreign_keyn('classnum', 'usage_class', 'classnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

