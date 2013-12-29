package FS::part_pkg_msgcat;
use base qw( FS::Record );

use strict;
use FS::Locales;

=head1 NAME

FS::part_pkg_msgcat - Object methods for part_pkg_msgcat records

=head1 SYNOPSIS

  use FS::part_pkg_msgcat;

  $record = new FS::part_pkg_msgcat \%hash;
  $record = new FS::part_pkg_msgcat { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_msgcat object represents localized labels of a package
definition.  FS::part_pkg_msgcat inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item pkgpartmsgnum

primary key

=item pkgpart

Package definition

=item locale

locale

=item pkg

Localized package name (customer-viewable)

=item comment

Localized package comment (non-customer-viewable), optional

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_pkg_msgcat'; }

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
    $self->ut_numbern('pkgpartmsgnum')
    || $self->ut_foreign_key('pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_enum('locale', [ FS::Locales->locales ] )
    || $self->ut_text('pkg')
    || $self->ut_textn('comment')
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

