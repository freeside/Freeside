package FS::phone_avail;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::phone_avail - Phone number availability cache

=head1 SYNOPSIS

  use FS::phone_avail;

  $record = new FS::phone_avail \%hash;
  $record = new FS::phone_avail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::phone_avail object represents availability of phone service.
FS::phone_avail inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item availnum

primary key

=item exportnum

exportnum

=item countrycode

countrycode

=item state

state

=item npa

npa

=item nxx

nxx

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'phone_avail'; }

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
    $self->ut_numbern('availnum')
    || $self->ut_foreign_key('exportnum', 'part_export', 'exportnum' )
    || $self->ut_number('countrycode')
    || $self->ut_alphan('state')
    || $self->ut_number('npa')
    || $self->ut_numbern('nxx')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Sparse documentation.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

