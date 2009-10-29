package FS::category_Common;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch );

=head1 NAME

FS::category_Common - Base class for category (group of classifications) classes

=head1 SYNOPSIS

use base qw( FS::category_Common );
use FS::class_table; #should use this

#optional for non-standard names
sub _class_table { 'table_name'; } #default is to replace s/category/class/

=head1 DESCRIPTION

FS::category_Common is a base class for classes which provide a categorization
(group of classifications) for other classes, such as pkg_category or
cust_category.

=item delete

Deletes this category from the database.  Only categories with no associated
classifications can be deleted.  If there is an error, returns the error,
otherwise returns false.

=cut

sub delete {
  my $self = shift;

  return "Can't delete a ". $self->table.
         " with ". $self->_class_table. " records!"
    if qsearch( $self->_class_table, { 'categorynum' => $self->categorynum } );

  $self->SUPER::delete;
}

=item check

Checks all fields to make sure this is a valid package category.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  $self->ut_numbern('categorynum')
    or $self->ut_text('categoryname')
    or $self->ut_snumbern('weight')
    or $self->ut_enum('disabled', [ '', 'Y' ])
    or $self->SUPER::check;

}

=back

=cut

#defaults

use vars qw( $_class_table );
sub _class_table {
  return $_class_table if $_class_table;
  my $self = shift;
  $_class_table = $self->table;
  $_class_table =~ s/category/cclass/ # s/_category$/_class/
    or die "can't determine an automatic class table for $_class_table";
  $_class_table;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

