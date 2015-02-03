package FS::cust_contact;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cust_contact - Object methods for cust_contact records

=head1 SYNOPSIS

  use FS::cust_contact;

  $record = new FS::cust_contact \%hash;
  $record = new FS::cust_contact { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_contact object represents a contact's attachment to a specific
customer.  FS::cust_contact inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item custcontactnum

primary key

=item custnum

custnum

=item contactnum

contactnum

=item classnum

classnum

=item comment

comment

=item selfservice_access

empty or Y

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_contact'; }

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

  if ( $self->selfservice_access eq 'R' ) {
    $self->selfservice_access('Y');
    $self->_resend('Y');
  }

  my $error = 
    $self->ut_numbern('custcontactnum')
    || $self->ut_number('custnum')
    || $self->ut_number('contactnum')
    || $self->ut_numbern('classnum')
    || $self->ut_textn('comment')
    || $self->ut_enum('selfservice_access', [ '', 'Y' ])
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item contact_classname

Returns the name of this contact's class (see L<FS::contact_class>).

=cut

sub contact_classname {
  my $self = shift;
  my $contact_class = $self->contact_class or return '';
  $contact_class->classname;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::contact>, L<FS::cust_main>, L<FS::Record>

=cut

1;

