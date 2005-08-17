package FS::payment_gateway;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::option_Common;

@ISA = qw( FS::option_Common );

=head1 NAME

FS::payment_gateway - Object methods for payment_gateway records

=head1 SYNOPSIS

  use FS::payment_gateway;

  $record = new FS::payment_gateway \%hash;
  $record = new FS::payment_gateway { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::payment_gateway object represents an payment gateway.
FS::payment_gateway inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item gatewaynum - primary key

=item gateway_module - Business::OnlinePayment:: module name

=item gateway_username - payment gateway username

=item gateway_password - payment gateway password

=item gateway_action - optional action or actions (multiple actions are separated with `,': for example: `Authorization Only, Post Authorization').  Defaults to `Normal Authorization'.

=item disabled - Disabled flag, empty or 'Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new payment gateway.  To add the payment gateway to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'payment_gateway'; }

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

Checks all fields to make sure this is a valid payment gateway.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('gatewaynum')
    || $self->ut_alpha('gateway_module')
    || $self->ut_textn('gateway_username')
    || $self->ut_anything('gateway_password')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    #|| $self->ut_textn('gateway_action')
  ;
  return $error if $error;

  if ( $self->gateway_action ) {
    my @actions = split(/,\s*/, $self->gateway_action);
    $self->gateway_action(
      join( ',', map { /^(Normal Authorization|Authorization Only|Credit|Post Authorization)$/
                         or return "Unknown action $_";
                       $1
                     }
                     @actions
          )
   );
  } else {
    $self->gateway_action('Normal Authorization');
  }

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

