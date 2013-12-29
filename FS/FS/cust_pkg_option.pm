package FS::cust_pkg_option;
use base qw(FS::Record);

use strict;

=head1 NAME

FS::cust_pkg_option - Object methods for cust_pkg_option records

=head1 SYNOPSIS

  use FS::cust_pkg_option;

  $record = new FS::cust_pkg_option \%hash;
  $record = new FS::cust_pkg_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pkg_option object represents an option key an value for a
customer package.  FS::cust_pkg_option inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item optionnum - primary key

=item pkgnum - 

=item optionname - 

=item optionvalue - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new option.  To add the option to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_pkg_option'; }

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

Checks all fields to make sure this is a valid option.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('optionnum')
    || $self->ut_foreign_key('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_text('optionname')
    || $self->ut_textn('optionvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

