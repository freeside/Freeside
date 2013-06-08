package FS::currency_exchange;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::currency_exchange - Object methods for currency_exchange records

=head1 SYNOPSIS

  use FS::currency_exchange;

  $record = new FS::currency_exchange \%hash;
  $record = new FS::currency_exchange { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::currency_exchange object represents an exchange rate between currencies.
FS::currency_exchange inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item currencyratenum

primary key

=item from_currency

from_currency

=item to_currency

to_currency

=item rate

rate


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new exchange rate.  To add the exchange rate to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'currency_exchange'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid exchange rate.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('currencyratenum')
    || $self->ut_currency('from_currency')
    || $self->ut_currency('to_currency')
    || $self->ut_float('rate') #good enough for untainting
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

