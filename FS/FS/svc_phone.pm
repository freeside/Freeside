package FS::svc_phone;

use strict;
use vars qw( @ISA );
#use FS::Record qw( qsearch qsearchs );
use FS::svc_Common;

@ISA = qw( FS::svc_Common );

=head1 NAME

FS::svc_phone - Object methods for svc_phone records

=head1 SYNOPSIS

  use FS::svc_phone;

  $record = new FS::svc_phone \%hash;
  $record = new FS::svc_phone { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_phone object represents a phone number.  FS::svc_phone inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item svcnum - primary key

=item countrycode - 

=item phonenum - 

=item pin - 

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new phone number.  To add the number to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'svc_phone'; }

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

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid phone number.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('countrycode')
    || $self->ut_number('phonenum')
    || $self->ut_numbern('pin')
  ;
  return $error if $error;

  $self->countrycode(1) unless $self->countrycode;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

