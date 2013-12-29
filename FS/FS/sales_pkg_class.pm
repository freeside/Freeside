package FS::sales_pkg_class;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::sales_pkg_class - Object methods for sales_pkg_class records

=head1 SYNOPSIS

  use FS::sales_pkg_class;

  $record = new FS::sales_pkg_class \%hash;
  $record = new FS::sales_pkg_class { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::sales_pkg_class object represents a commission for a specific sales
person and package class.  FS::sales_pkg_class inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item salespkgclassnum

primary key

=item salesnum

salesnum

=item classnum

classnum

=item commission_percent

commission_percent

=item commission_duration

commission_duration


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'sales_pkg_class'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->commission_percent(0) unless length($self->commission_percent);

  my $error = 
    $self->ut_numbern('salespkgclassnum')
    || $self->ut_foreign_key('salesnum', 'sales', 'salesnum')
    || $self->ut_foreign_keyn('classnum', 'pkg_class', 'classnum')
    || $self->ut_float('commission_percent')
    || $self->ut_numbern('commission_duration')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub classname {
  my $self = shift;
  my $pkg_class = $self->pkg_class;
  $pkg_class ? $pkg_class->classname : '(no package class)';
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::sales>, L<FS::pkg_class, L<FS::Record>.

=cut

1;

