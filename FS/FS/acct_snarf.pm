package FS::acct_snarf;

use strict;
use vars qw( @ISA );
use FS::Record;

@ISA = qw( FS::Record );

=head1 NAME

FS::acct_snarf - Object methods for acct_snarf records

=head1 SYNOPSIS

  use FS::acct_snarf;

  $record = new FS::acct_snarf \%hash;
  $record = new FS::acct_snarf { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_acct object represents an external mail account, typically for
download of mail.  FS::acct_snarf inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item snarfnum - primary key

=item svcnum - Account (see L<FS::svc_acct>)

=item machine - external machine to download mail from

=item protocol - protocol (pop3, imap, etc.)

=item username - external login username

=item _password - external login password

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'acct_snarf'; }

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

Checks all fields to make sure this is a valid external mail account.  If
there is an error, returns the error, otherwise returns false.  Called by the
insert and replace methods.

=cut

sub check {
  my $self = shift;
  my $error =
       $self->ut_numbern('snarfnum')
    || $self->ut_number('svcnum')
    || $self->ut_foreign_key('svcnum', 'svc_acct', 'svcnum')
    || $self->ut_domain('machine')
    || $self->ut_alphan('protocol')
    || $self->ut_textn('username')
  ;
  return $error if $error;

  $self->_password =~ /^[^\t\n]*$/ or return "illegal password";
  $self->_password($1);

  ''; #no error
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

