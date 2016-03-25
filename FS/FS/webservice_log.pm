package FS::webservice_log;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::webservice_log - Object methods for webservice_log records

=head1 SYNOPSIS

  use FS::webservice_log;

  $record = new FS::webservice_log \%hash;
  $record = new FS::webservice_log { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::webservice_log object represents an web service log entry.
FS::webservice_log inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item webservicelognum

primary key

=item svcnum

svcnum

=item custnum

custnum

=item method

method

=item quantity

quantity

=item _date

_date

=item status

status

=item rated_price

rated_price


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new log entry.  To add the log entry to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined
sub table { 'webservice_log'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid log entry.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('webservicelognum')
    || $self->ut_foreign_keyn('svcnum', 'cust_svc', 'svcnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_text('method')
    || $self->ut_number('quantity')
    || $self->ut_numbern('_date')
    || $self->ut_alphan('status')
    || $self->ut_moneyn('rated_price')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

