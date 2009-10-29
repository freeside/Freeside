package FS::class_Common;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::class_Common - Base class for classification classes

=head1 SYNOPSIS

use base qw( FS::class_Common );
use FS::category_table; #should use this

#required
sub _target_table { 'table_name'; }

#optional for non-standard names
sub _target_column { 'classnum'; } #default is classnum
sub _category_table { 'table_name'; } #default is to replace s/class/category/

=head1 DESCRIPTION

FS::class_Common is a base class for classes which provide a classification for
other classes, such as pkg_class or cust_class.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new classification.  To add the classfication to the database, see
L<"insert">.

=cut

=item insert

Adds this classification to the database.  If there is an error, returns the
error, otherwise returns false.

=item delete

Deletes this classification from the database.  Only classifications with no
associated target objects can be deleted.  If there is an error, returns
the error, otherwise returns false.

=cut

sub delete {
  my $self = shift;

  return "Can't delete a ". $self->table.
         " with ". $self->_target_table. " records!"
    if qsearch( $self->_target_table,
                { $self->_target_column => $self->classnum }
              );

  $self->SUPER::delete;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid package classification.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('classnum')
    or $self->ut_text('classname')
    or $self->ut_foreign_keyn( 'categorynum',
                               $self->_category_table,
                               'categorynum',
                             )
    or $self->ut_enum('disabled', [ '', 'Y' ] )
    or $self->SUPER::check;

}

=item category

Returns the category record associated with this class, or false if there is
none.

=cut

sub category {
  my $self = shift;
  qsearchs($self->_category_table, { 'categorynum' => $self->categorynum } );
}

=item categoryname

Returns the category name associated with this class, or false if there
is none.

=cut

sub categoryname {
  my $category = shift->category;
  $category ? $category->categoryname : '';
}

#required
sub _target_table {
  my $self = shift;
  die "_target_table unspecified for $self";
}

#defaults

sub _target_column { 'classnum'; }

use vars qw( $_category_table );
sub _category_table {
  return $_category_table if $_category_table;
  my $self = shift;
  $_category_table = $self->table;
  $_category_table =~ s/class/category/ # s/_class$/_category/
    or die "can't determine an automatic category table for $_category_table";
  $_category_table;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::category_Common>, L<FS::pkg_class>, L<FS::cust_class>

=cut

1;
