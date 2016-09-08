package FS::saved_search_option;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::saved_search_option - Object methods for saved_search_option records

=head1 SYNOPSIS

  use FS::saved_search_option;

  $record = new FS::saved_search_option \%hash;
  $record = new FS::saved_search_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::saved_search_option object represents a CGI parameter for a report
saved in L<FS::saved_search>.  FS::saved_search_option inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item optionnum

primary key

=item searchnum

searchnum

=item optionname

optionname

=item optionvalue

optionvalue


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new parameter.  To add the record to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'saved_search_option'; }

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

# unpack these from the format used by CGI
  my $optionvalue = $self->optionvalue;
  $optionvalue =~ s/\0/\n/g;

  my $error = 
    $self->ut_numbern('optionnum')
    || $self->ut_number('searchnum')
#   || $self->ut_foreign_key('searchnum', 'saved_search', 'searchnum')
    || $self->ut_text('optionname')
    || $self->ut_textn('optionvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>

=cut

1;

