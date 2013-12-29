package FS::contact_email;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::contact_email - Object methods for contact_email records

=head1 SYNOPSIS

  use FS::contact_email;

  $record = new FS::contact_email \%hash;
  $record = new FS::contact_email { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::contact_email object represents a contact's email address.
FS::contact_email inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item contactemailnum

primary key

=item contactnum

contactnum

=item emailaddress

emailaddress


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new contact email address.  To add the email address to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'contact_email'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid email address.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('contactemailnum')
    || $self->ut_number('contactnum')
  ;
  return $error if $error;

  #technically \w and also ! # $ % & ' * + - / = ? ^ _ ` { | } ~
  # and even more technically need to deal with i18n addreesses soon
  #  (maybe the UI can convert them for us ala punycode.js)
  # but for now in practice have not encountered anything outside \w . - & + '
  #  and even & and ' are super rare and probably have scarier "pass to shell"
  #   implications than worth being pedantic about accepting
  #    (we always String::ShellQuote quote them, but once passed...)
  #                              SO: \w . - +
  if ( $self->emailaddress =~ /^\s*([\w\.\-\+]+)\@(([\w\.\-]+\.)+\w+)\s*$/ ) {
    my($user, $domain) = ($1, $2);
    $self->emailaddress("$1\@$2");
  } else {
    return gettext("illegal_email_invoice_address"). ': '. $self->emailaddress;
  }

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::contact>, L<FS::Record>

=cut

1;

