package FS::payinfo_Mixin;

use strict;
use Business::CreditCard;
use FS::payby;

=head1 NAME

FS::payinfo_Mixin - Mixin class for records in tables that contain payinfo.  

=head1 SYNOPSIS

package FS::some_table;
use vars qw(@ISA);
@ISA = qw( FS::payinfo_Mixin FS::Record );

=head1 DESCRIPTION

This is a mixin class for records that contain payinfo. 

=head1 FIELDS

=over 4

=item payby

The following payment types (payby) are supported:

For Customers (cust_main):
'CARD' (credit card - automatic), 'DCRD' (credit card - on-demand),
'CHEK' (electronic check - automatic), 'DCHK' (electronic check - on-demand),
'LECB' (Phone bill billing), 'BILL' (billing), 'COMP' (free), or
'PREPAY' (special billing type: applies a credit and sets billing type to I<BILL> - see L<FS::prepay_credit>)

For Refunds (cust_refund):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (Phone bill billing), 'BILL' (billing), 'CASH' (cash),
'WEST' (Western Union), 'MCRD' (Manual credit card), 'CBAK' Chargeback, or 'COMP' (free)


For Payments (cust_pay):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (phone bill billing), 'BILL' (billing), 'PREP' (prepaid card),
'CASH' (cash), 'WEST' (Western Union), or 'MCRD' (Manual credit card)
'COMP' (free) is depricated as a payment type in cust_pay

=cut 

# was this supposed to do something?
 
#sub payby {
#  my($self,$payby) = @_;
#  if ( defined($payby) ) {
#    $self->setfield('payby', $payby);
#  } 
#  return $self->getfield('payby')
#}

=item payinfo

Payment information (payinfo) can be one of the following types:

Card Number, P.O., comp issuer (4-8 lowercase alphanumerics; think username) or prepayment identifier (see L<FS::prepay_credit>)

=cut

sub payinfo {
  my($self,$payinfo) = @_;

  if ( defined($payinfo) ) {
    $self->setfield('payinfo', $payinfo);
    $self->paymask($self->mask_payinfo) unless $payinfo =~ /^99\d{14}$/; #token
  } else {
    $self->getfield('payinfo');
  }
}

=item paycvv

Card Verification Value, "CVV2" (also known as CVC2 or CID), the 3 or 4 digit number on the back (or front, for American Express) of the credit card

=cut

sub paycvv {
  my($self,$paycvv) = @_;
  # This is only allowed in cust_main... Even then it really shouldn't be stored...
  if ($self->table eq 'cust_main') {
    if ( defined($paycvv) ) {
      $self->setfield('paycvv', $paycvv); # This is okay since we are the 'setter'
    } else {
      $paycvv = $self->getfield('paycvv'); # This is okay since we are the 'getter'
      return $paycvv;
    }
  } else {
#    warn "This doesn't work for other tables besides cust_main
    '';
  } 
}

=item paymask

=cut

sub paymask {
  my($self, $paymask) = @_;

  if ( defined($paymask) ) {
    $self->setfield('paymask', $paymask);
  } else {
    $self->getfield('paymask') || $self->mask_payinfo;
  }
}

=back

=head1 METHODS

=over 4

=item mask_payinfo [ PAYBY, PAYINFO ]

This method converts the payment info (credit card, bank account, etc.) into a
masked string.

Optionally, an arbitrary payby and payinfo can be passed.

=cut

sub mask_payinfo {
  my $self = shift;
  my $payby   = scalar(@_) ? shift : $self->payby;
  my $payinfo = scalar(@_) ? shift : $self->payinfo;

  # Check to see if it's encrypted...
  my $paymask;
  if ( $self->is_encrypted($payinfo) ) {
    $paymask = 'N/A';
  } elsif ( $payinfo =~ /^99\d{14}$/ || $payinfo eq 'N/A' ) { #token
    $paymask = 'N/A (tokenized)'; #?
  } else {
    # if not, mask it...
    if ($payby eq 'CARD' || $payby eq 'DCRD' || $payby eq 'MCRD') {
      # Credit Cards
      my $conf = new FS::Conf;
      my $mask_method = $conf->config('card_masking_method') || 'first6last4';
      $mask_method =~ /^first(\d+)last(\d+)$/
        or die "can't parse card_masking_method $mask_method";
      my($first, $last) = ($1, $2);

      $paymask = substr($payinfo,0,$first).
                 'x'x(length($payinfo)-$first-$last).
                 substr($payinfo,(length($payinfo)-$last));
    } elsif ($payby eq 'CHEK' || $payby eq 'DCHK' ) {
      # Checks (Show last 2 @ bank)
      my( $account, $aba ) = split('@', $payinfo );
      $paymask = 'x'x(length($account)-2).
                 substr($account,(length($account)-2))."@".$aba;
    } else { # Tie up loose ends
      $paymask = $payinfo;
    }
  }
  $paymask;
}

=item payinfo_check

Checks payby and payinfo.

For Customers (cust_main):
'CARD' (credit card - automatic), 'DCRD' (credit card - on-demand),
'CHEK' (electronic check - automatic), 'DCHK' (electronic check - on-demand),
'LECB' (Phone bill billing), 'BILL' (billing), 'COMP' (free), or
'PREPAY' (special billing type: applies a credit - see L<FS::prepay_credit> and sets billing type to I<BILL>)

For Refunds (cust_refund):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (Phone bill billing), 'BILL' (billing), 'CASH' (cash),
'WEST' (Western Union), 'MCRD' (Manual credit card), 'CBAK' (Chargeback),  or 'COMP' (free)

For Payments (cust_pay):
'CARD' (credit cards), 'CHEK' (electronic check/ACH),
'LECB' (phone bill billing), 'BILL' (billing), 'PREP' (prepaid card),
'CASH' (cash), 'WEST' (Western Union), or 'MCRD' (Manual credit card)
'COMP' (free) is depricated as a payment type in cust_pay

=cut

sub payinfo_check {
  my $self = shift;

  FS::payby->can_payby($self->table, $self->payby)
    or return "Illegal payby: ". $self->payby;

  if ( $self->payby eq 'CARD' && ! $self->is_encrypted($self->payinfo) ) {
    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $self->payinfo($payinfo);
    if ( $self->payinfo ) {
      $self->payinfo =~ /^(\d{13,16})$/
        or return "Illegal (mistyped?) credit card number (payinfo)";
      $self->payinfo($1);
      validate($self->payinfo) or return "Illegal credit card number";
      return "Unknown card type" if $self->payinfo !~ /^99\d{14}$/ #token
                                 && cardtype($self->payinfo) eq "Unknown";
    } else {
      $self->payinfo('N/A'); #???
    }
  } else {
    if ( $self->is_encrypted($self->payinfo) ) {
      #something better?  all it would cause is a decryption error anyway?
      my $error = $self->ut_anything('payinfo');
      return $error if $error;
    } else {
      my $error = $self->ut_textn('payinfo');
      return $error if $error;
    }
  }

  '';

}

=item payby_payinfo_pretty

Returns payment method and information (suitably masked, if applicable) as
a human-readable string, such as:

  Card #54xxxxxxxxxxxx32

or

  Check #119006

=cut

sub payby_payinfo_pretty {
  my $self = shift;
  if ( $self->payby eq 'CARD' ) {
    'Card #'. $self->paymask;
  } elsif ( $self->payby eq 'CHEK' ) {
    'E-check acct#'. $self->payinfo;
  } elsif ( $self->payby eq 'BILL' ) {
    'Check #'. $self->payinfo;
  } elsif ( $self->payby eq 'PREP' ) {
    'Prepaid card #'. $self->payinfo;
  } elsif ( $self->payby eq 'CASH' ) {
    'Cash '. $self->payinfo;
  } elsif ( $self->payby eq 'WEST' ) {
    'Western Union'; #. $self->payinfo;
  } elsif ( $self->payby eq 'MCRD' ) {
    'Manual credit card'; #. $self->payinfo;
  } else {
    $self->payby. ' '. $self->payinfo;
  }
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::payby>, L<FS::Record>

=cut

1;

