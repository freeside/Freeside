package FS::qual_option;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::qual;

=head1 NAME

FS::qual_option - Object methods for qual_option records

=head1 SYNOPSIS

  use FS::qual_option;

  $record = new FS::qual_option \%hash;
  $record = new FS::qual_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::qual_option object represents a qualification option. 
FS::qual_option inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item optionnum - primary key

=item qualnum - qualification (see L<FS::qual>)

=item optionname - option name

=item optionvalue - option value


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new qualification option. To add the qualification option to the
database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'qual_option'; }

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

Checks all fields to make sure this is a valid qualification option.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('optionnum')
    || $self->ut_foreign_key('qualnum', 'qual', 'qualnum')
    || $self->ut_alpha('optionname')
    || $self->ut_textn('optionvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

This doesn't do anything yet.

=head1 SEE ALSO

L<FS::qual>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

