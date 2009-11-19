package FS::cdr_batch;

use strict;
use base qw( FS::Record );
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cdr_batch - Object methods for cdr_batch records

=head1 SYNOPSIS

  use FS::cdr_batch;

  $record = new FS::cdr_batch \%hash;
  $record = new FS::cdr_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cdr_batch object represents a CDR batch.  FS::cdr_batch inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item cdrbatchnum

primary key

=item cdrbatch

cdrbatch

=item _date

_date


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new batch.  To add the batch to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cdr_batch'; }

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

Checks all fields to make sure this is a valid batch.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('cdrbatchnum')
    || $self->ut_textn('cdrbatch')
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cdr>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

