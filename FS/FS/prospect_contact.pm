package FS::prospect_contact;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::prospect_contact - Object methods for prospect_contact records

=head1 SYNOPSIS

  use FS::prospect_contact;

  $record = new FS::prospect_contact \%hash;
  $record = new FS::prospect_contact { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::prospect_contact object represents a contact's attachment to a specific
prospect.  FS::prospect_contact inherits from FS::Record.  The following fields
are currently supported:

=over 4

=item prospectcontactnum

primary key

=item prospectnum

prospectnum

=item contactnum

contactnum

=item classnum

classnum

=item comment

comment


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'prospect_contact'; }

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

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('prospectcontactnum')
    || $self->ut_number('prospectnum')
    || $self->ut_number('contactnum')
    || $self->ut_numbern('classnum')
    || $self->ut_textn('comment')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::contact>, L<FS::prospect_main>, L<FS::Record>

=cut

1;

