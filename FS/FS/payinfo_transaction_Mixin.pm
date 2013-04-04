package FS::payinfo_transaction_Mixin;

use strict;
use vars qw( @ISA );
use FS::payby;
use FS::payinfo_Mixin;
use FS::Record qw(qsearchs);
use FS::cust_main;
use FS::payment_gateway;

@ISA = qw( FS::payinfo_Mixin );

=head1 NAME

FS::payinfo_transaction_Mixin - Mixin class for records in tables that represent transactions.

=head1 SYNOPSIS

package FS::some_table;
use vars qw(@ISA);
@ISA = qw( FS::payinfo_transaction_Mixin FS::Record );

=head1 DESCRIPTION

This is a mixin class for records that represent transactions: that contain
payinfo and realtime result fields (gatewaynum, processor, authorization,
order_number).  Currently FS::cust_pay, FS::cust_refund, and FS::cust_pay_void.

=head1 METHODS

=over 4

=item cust_main

Returns the parent customer object (see L<FS::cust_main>).

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=item payby_name

Returns a name for the payby field.

=cut

sub payby_name {
  my $self = shift;
  if ( $self->payby eq 'BILL' ) { #kludge
    'Check';
  } else {
    FS::payby->shortname( $self->payby );
  }
}

# We keep _parse_paybatch just because the upgrade needs it.

sub _parse_paybatch {
  my $self = shift;

  $self->paybatch =~ /^((\d+)\-)?(\w+):\s*([\w\-\/ ]*)(:([\w\-]+))?$/
    or return {};
              #"Can't parse paybatch for paynum $options{'paynum'}: ".
              #  $cust_pay->paybatch;

  my( $gatewaynum, $processor, $auth, $order_number ) = ( $2, $3, $4, $6 );

  if ( $gatewaynum ) { #gateway for the payment to be refunded

    my $payment_gateway =
      qsearchs('payment_gateway', { 'gatewaynum' => $gatewaynum } );

    $processor = $payment_gateway->gateway_module if $payment_gateway;

  }

  {
    'gatewaynum'    => $gatewaynum,
    'processor'     => $processor,
    'authorization' => $auth,
    'order_number'  => $order_number,
  };

}

# because we can't actually name the field 'authorization' (reserved word)
sub authorization {
  my $self = shift;
  $self->auth(@_);
}

=item payinfo_check

Checks the validity of the realtime payment fields (gatewaynum, processor,
auth, and order_number) as well as payby and payinfo

=cut

sub payinfo_check {
  my $self = shift;

  # All of these can be null, so in principle this could go in payinfo_Mixin.

  $self->SUPER::payinfo_check()
  || $self->ut_numbern('gatewaynum')
  # not ut_foreign_keyn, it causes upgrades to fail
  || $self->ut_alphan('processor')
  || $self->ut_textn('auth')
  || $self->ut_textn('order_number')
  || '';
}

=back

=head1 SEE ALSO

L<FS::payinfo_Mixin>

=cut

1;
