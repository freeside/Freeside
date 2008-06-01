package FS::payinfo_transaction_Mixin;

use strict;
use vars qw( @ISA );
use FS::payby;
use FS::payinfo_Mixin;

@ISA = qw( FS::payinfo_Mixin );

=head1 NAME

FS::payinfo_transaction_Mixin - Mixin class for records in tables that represent transactions.

=head1 SYNOPSIS

package FS::some_table;
use vars qw(@ISA);
@ISA = qw( FS::payinfo_transaction_Mixin FS::Record );

=head1 DESCRIPTION

This is a mixin class for records that represent transactions: that contain
payinfo and paybatch.  Currently FS::cust_pay and FS::cust_refund

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

=item gatewaynum

Returns a gatewaynum for the processing gateway.

=item processor

Returns a name for the processing gateway.

=item authorization

Returns a name for the processing gateway.

=item order_number

Returns a name for the processing gateway.

=cut

sub gatewaynum    { shift->_parse_paybatch->{'gatewaynum'}; }
sub processor     { shift->_parse_paybatch->{'processor'}; }
sub authorization { shift->_parse_paybatch->{'authorization'}; }
sub order_number  { shift->_parse_paybatch->{'order_number'}; }

#sucks that this stuff is in paybatch like this in the first place,
#but at least other code can start to use new field names
#(code nicked from FS::cust_main::realtime_refund_bop)
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

    die "payment gateway $gatewaynum not found" #?
      unless $payment_gateway;

    $processor = $payment_gateway->gateway_module;

  }

  {
    'gatewaynum'    => $gatewaynum,
    'processor'     => $processor,
    'authorization' => $auth,
    'order_number'  => $order_number,
  };

}




=back

=head1 SEE ALSO

L<FS::payinfo_Mixin>

=back
