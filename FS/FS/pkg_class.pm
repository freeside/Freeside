package FS::pkg_class;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs qsearch );
use FS::part_pkg;
use FS::pkg_category;

@ISA = qw( FS::Record );

=head1 NAME

FS::pkg_class - Object methods for pkg_class records

=head1 SYNOPSIS

  use FS::pkg_class;

  $record = new FS::pkg_class \%hash;
  $record = new FS::pkg_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::pkg_class object represents an package class.  Every package definition
(see L<FS::part_pkg>) has, optionally, a package class. FS::pkg_class inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item classnum - primary key (assigned automatically for new package classes)

=item classname - Text name of this package class

=item categorynum - Number of associated pkg_category (see L<FS::pkg_category>)

=item disabled - Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new package class.  To add the package class to the database, see
L<"insert">.

=cut

sub table { 'pkg_class'; }

=item insert

Adds this package class to the database.  If there is an error, returns the
error, otherwise returns false.

=item delete

Deletes this package class from the database.  Only package classes with no
associated package definitions can be deleted.  If there is an error, returns
the error, otherwise returns false.

=cut

sub delete {
  my $self = shift;

  return "Can't delete an pkg_class with part_pkg records!"
    if qsearch( 'part_pkg', { 'classnum' => $self->classnum } );

  $self->SUPER::delete;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid package class.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('classnum')
  or $self->ut_text('classname')
  or $self->ut_foreign_keyn('categorynum', 'pkg_category', 'categorynum')
  or $self->SUPER::check;

}

=item pkg_category

Returns the pkg_category record associated with this class, or false if there
is none.

=cut

sub pkg_category {
  my $self = shift;
  qsearchs('pkg_category', { 'categorynum' => $self->categorynum } );
}

=item categoryname

Returns the category name associated with this class, or false if there
is none.

=cut

sub categoryname {
  my $pkg_category = shift->pkg_category;
  $pkg_category->categoryname if $pkg_category;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::part_pkg>, schema.html from the base documentation.

=cut

1;

