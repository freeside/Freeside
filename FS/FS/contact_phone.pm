package FS::contact_phone;
use base qw( FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::contact;

=head1 NAME

FS::contact_phone - Object methods for contact_phone records

=head1 SYNOPSIS

  use FS::contact_phone;

  $record = new FS::contact_phone \%hash;
  $record = new FS::contact_phone { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::contact_phone object represents a contatct's phone number.
FS::contact_phone inherits from FS::Record.  The following fields are currently supported:

=over 4

=item contactphonenum

primary key

=item contactnum

contactnum

=item phonetypenum

phonetypenum

=item countrycode

countrycode

=item phonenum

phonenum

=item extension

extension


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new phone number.  To add the phone number to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'contact_phone'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid phone number.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('contactphonenum')
    || $self->ut_number('contactnum')
    || $self->ut_number('phonetypenum')
    || $self->ut_text('countrycode')
    || $self->ut_text('phonenum')
    || $self->ut_textn('extension')
  ;
  return $error if $error;

  #strip non-digits, UI should format numbers per countrycode
  (my $phonenum = $self->phonenum ) =~ s/\D//g;
  $self->phonenum($phonenum);

  $self->SUPER::check;
}

sub phonenum_pretty {
  my $self = shift;

  #until/unless we have the upgrade strip all whitespace
  (my $phonenum = $self->phonenum ) =~ s/\D//g;

  if ( $self->countrycode == 1 ) {

    $phonenum =~ /^(\d{3})(\d{3})(\d{4})(\d*)$/
      or return $self->phonenum; #wtf?

    $phonenum = "($1) $2-$3";
    $phonenum .= " x$4" if $4;
    return $phonenum;

  } else {
    warn "don't know how to format phone numbers for country +". $self->countrycode;
    #also, the UI doesn't have a good way for you to enter them yet or parse a countrycode from the number
    return $self->phonenum;
  }

}

sub contact {
  my $self = shift;
  qsearchs( 'contact', { 'contactnum' => $self->contactnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::contact>, L<FS::Record>

=cut

1;

