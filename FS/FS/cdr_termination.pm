package FS::cdr_termination;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cdr_termination - Object methods for cdr_termination records

=head1 SYNOPSIS

  use FS::cdr_termination;

  $record = new FS::cdr_termination \%hash;
  $record = new FS::cdr_termination { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cdr_termination object represents an CDR termination status.
FS::cdr_termination inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item cdrtermnum

primary key

=item acctid

acctid

=item termpart

termpart

=item rated_price

rated_price

=item status

status


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cdr_termination'; }

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
    $self->ut_numbern('cdrtermnum')
    || $self->ut_foreign_key('acctid', 'cdr', 'acctid')
    #|| $self->ut_foreign_key('termpart', 'part_termination', 'termpart')
    || $self->ut_number('termpart')
    || $self->ut_float('rated_price')
    || $self->ut_enum('status', '', 'done' ) # , 'skipped' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item set_status_and_rated_price STATUS [ RATED_PRICE ]

Sets the status to the provided string.  If there is an error, returns the
error, otherwise returns false.

=cut

sub set_status_and_rated_price {
  my($self, $status, $rated_price) = @_;
  $self->status($status);
  $self->rated_price($rated_price);
  $self->replace();
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cdr>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

