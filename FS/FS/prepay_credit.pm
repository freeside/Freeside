package FS::prepay_credit;

use strict;
use vars qw( @ISA );
#use FS::Record qw( qsearch qsearchs );
use FS::Record qw();

@ISA = qw(FS::Record);

=head1 NAME

FS::prepay_credit - Object methods for prepay_credit records

=head1 SYNOPSIS

  use FS::prepay_credit;

  $record = new FS::prepay_credit \%hash;
  $record = new FS::prepay_credit {
    'identifier' => '4198123455512121'
    'amount'     => '19.95',
  };

  $record = new FS::prepay_credit {
    'identifier' => '4198123455512121'
    'seconds'    => '7200',
  };


  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::table_name object represents an pre--paid credit, such as a pre-paid
"calling card".  FS::prepay_credit inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item field - description

=item identifier - identifier entered by the user to receive the credit

=item amount - amount of the credit

=item seconds - time amount of credit (see L<FS::svc_acct/seconds>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new pre-paid credit.  To add the example to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'prepay_credit'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid pre-paid credit.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $identifier = $self->identifier;
  $identifier =~ s/\W//g; #anything else would just confuse things
  $self->identifier($identifier);

  $self->ut_numbern('prepaynum')
  || $self->ut_alpha('identifier')
  || $self->ut_money('amount')
  || $self->utnumbern('seconds')
  || $self->SUPER::check
  ;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_acct>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

