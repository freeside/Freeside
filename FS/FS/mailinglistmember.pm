package FS::mailinglistmember;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearchs ); # qsearch );
use FS::mailinglist;
use FS::svc_acct;
use FS::contact_email;

=head1 NAME

FS::mailinglistmember - Object methods for mailinglistmember records

=head1 SYNOPSIS

  use FS::mailinglistmember;

  $record = new FS::mailinglistmember \%hash;
  $record = new FS::mailinglistmember { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::mailinglistmember object represents a mailing list member.
FS::mailinglistmember inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item membernum

primary key

=item listnum

listnum

=item svcnum

svcnum

=item contactemailnum

contactemailnum

=item email

email


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new mailing list member.  To add the member to the database, see
 L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'mailinglistmember'; }

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

Checks all fields to make sure this is a valid member.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('membernum')
    || $self->ut_foreign_key('listnum', 'mailinglist', 'listnum')
    || $self->ut_foreign_keyn('svcnum', 'svc_acct', 'svcnum')
    || $self->ut_foreign_keyn('contactemailnum', 'contact_email', 'contactemailnum')
    || $self->ut_textn('email') #XXX ut_email! from svc_forward, cust_main_invoice
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item mailinglist

=cut

sub mailinglist {
  my $self = shift;
  qsearchs('mailinglist', { 'listnum' => $self->listnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

