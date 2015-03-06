package FS::legacy_cust_history;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::legacy_cust_history - Object methods for legacy_cust_history records

=head1 SYNOPSIS

  use FS::legacy_cust_history;

  $record = new FS::legacy_cust_history \%hash;
  $record = new FS::legacy_cust_history { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::legacy_cust_history object represents an item of customer change history
from a previous billing system.  FS::legacy_cust_history inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item legacyhistorynum

primary key

=item custnum

Customer (see L<FS::cust_main)

=item history_action

Action, such as add, edit, delete, etc.

=item history_date

Date, as a UNIX timestamp

=item history_usernum

Employee (see L<FS::access_user>)

=item item

The item (i.e. table) which was changed.

=item description

A text description of the change

=item change_data

A text data structure representing the change

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'legacy_cust_history'; }

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
    $self->ut_numbern('legacyhistorynum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_text('history_action')
    || $self->ut_numbern('history_date')
    || $self->ut_foreign_keyn('history_usernum', 'access_user', 'usernum')
    || $self->ut_textn('item')
    || $self->ut_textn('description')
    || $self->ut_anything('change_data')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

