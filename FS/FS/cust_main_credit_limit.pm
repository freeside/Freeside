package FS::cust_main_credit_limit;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;

=head1 NAME

FS::cust_main_credit_limit - Object methods for cust_main_credit_limit records

=head1 SYNOPSIS

  use FS::cust_main_credit_limit;

  $record = new FS::cust_main_credit_limit \%hash;
  $record = new FS::cust_main_credit_limit { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_main_credit_limit object represents a specific incident where a
customer exceeds their credit limit.  FS::cust_main_credit_limit inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item creditlimitnum

primary key

=item custnum

Customer (see L<FS::cust_main>)

=item _date

Ppecified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item amount

Amount of credit of the incident

=item credit_limit

Appliable customer or default credit_limit at the time of the incident

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_main_credit_limit'; }

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

  my $error = 
    $self->ut_numbern('creditlimitnum')
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'custnum')
    || $self->ut_number('_date')
    || $self->ut_money('amount')
    || $self->ut_money('credit_limit')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub cust_main {
  my $self = shift;
  qsearchs('cust_main', { 'custnum' => $self->custnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

