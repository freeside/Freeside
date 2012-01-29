package FS::payby;

use strict;
use vars qw(%hash %payby2bop);
use Tie::IxHash;
use Business::CreditCard;


=head1 NAME

FS::payby - Object methods for payment type records

=head1 SYNOPSIS

  use FS::payby;

  #for now...

  my @payby = FS::payby->payby;

  my $bool = FS::payby->can_payby('cust_main', 'CARD');

  tie my %payby, 'Tie::IxHash', FS::payby->payby2longname

  my @cust_payby = FS::payby->cust_payby;

  tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2longname

=head1 DESCRIPTION

Payment types.

=head1 METHODS

=over 4 

=item

=cut

# paybys can be any/all of:
# - a customer payment type (cust_main.payby)
# - a payment or refund type (cust_pay.payby, cust_pay_batch.payby, cust_refund.payby)
# - an event type (part_bill_event.payby)

tie %hash, 'Tie::IxHash',
  'CARD' => {
    tinyname  => 'card',
    shortname => 'Credit card',
    longname  => 'Credit card (automatic)',
    realtime  => 1,
  },
  'DCRD' => {
    tinyname  => 'card',
    shortname => 'Credit card',
    longname  => 'Credit card (on-demand)',
    cust_pay  => 'CARD', #this is a customer type only, payments are CARD...
    realtime  => 1,
  },
  'CHEK' => {
    tinyname  => 'check',
    shortname => 'Electronic check',
    longname  => 'Electronic check (automatic)',
    realtime  => 1,
  },
  'DCHK' => {
    tinyname  => 'check',
    shortname => 'Electronic check',
    longname  => 'Electronic check (on-demand)',
    cust_pay  => 'CHEK', #this is a customer type only, payments are CHEK...
    realtime  => 1,
  },
  'LECB' => {
    tinyname  => 'phone bill',
    shortname => 'Phone bill billing',
    longname  => 'Phone bill billing',
    realtime  => 1,
  },
  'BILL' => {
    tinyname  => 'billing',
    shortname => 'Billing',
    payname   => 'Check',
    longname  => 'Billing',
  },
  'PPAL' => {
    tinyname  => 'PayPal',
    shortname => 'PayPal',
    longname  => 'PayPal',
    cust_main => '', #not yet a customer type, but could be once we can do
                     # invoice presentment via paypal
  },
  'PREP' => {
    tinyname  => 'prepaid card',
    shortname => 'Prepaid card',
    longname  => 'Prepaid card',
    cust_main => 'BILL', #this is a payment type only, customers go to BILL...
  },
  'CASH' => {
    tinyname  => 'cash',
    shortname => 'Cash', # initial payment, then billing
    longname  => 'Cash',
    cust_main => 'BILL', #this is a payment type only, customers go to BILL...
  },
  'WEST' => {
    tinyname  => 'western union',
    shortname => 'Western Union', # initial payment, then billing
    longname  => 'Western Union',
    cust_main => 'BILL', #this is a payment type only, customers go to BILL...
  },
  'MCRD' => { #not the same as DCRD
    tinyname  => 'card',
    shortname => 'Manual credit card', # initial payment, then billing
    longname  => 'Manual credit card', 
    cust_main => 'BILL', #this is a payment type only, customers go to BILL...
  },
  'APPL' => {
    tinyname  => 'apple store',
    shortname => 'Apple Store',
    longname  => 'Apple Store',
    cust_main => 'BILL', #this is a payment type only, customers go to BILL...
  },
  'ANRD' => {
    tinyname  => 'android market',
    shortname => 'Android Market',
    longname  => 'Android Market',
    cust_main => 'BILL', #this is a payment type only, customers go to BILL...
  },
  'EDI' => {
    tinyname  => 'EDI',
    shortname => 'Electronic Debit',
    longname  => 'Electronic Debit',
    cust_main => '', #not a customer type
  },
  'WIRE' => {
    tinyname  => 'Wire',
    shortname => 'Wire transfer',
    longname  => 'Wire transfer',
    cust_main => '', #not a customer type
  },
  'COMP' => {
    tinyname  => 'comp',
    shortname => 'Complimentary',
    longname  => 'Complimentary',
    cust_pay  => '', # (free) is depricated as a payment type in cust_pay
  },
  'CBAK' => {
    tinyname  => 'chargeback',
    shortname => 'Chargeback',
    longname  => 'Chargeback',
    cust_main => '', # not a customer type
  },
;

sub payby {
  keys %hash;
}

sub can_payby {
  my( $self, $table, $payby ) = @_;

  #return "Illegal payby" unless $hash{$payby};
  return 0 unless $hash{$payby};

  $table = 'cust_pay' if $table =~ /^cust_(pay_pending|pay_batch|pay_void|refund)$/;
  return 0 if exists( $hash{$payby}->{$table} );

  return 1;
}

sub realtime {  # can use realtime payment facilities
  my( $self, $payby ) = @_;

  return 0 unless $hash{$payby};
  return 0 unless exists( $hash{$payby}->{realtime} );

  return $hash{$payby}->{realtime};
}

sub payby2longname {
  my $self = shift;
  map { $_ => $hash{$_}->{longname} } $self->payby;
}

sub shortname {
  my( $self, $payby ) = @_;
  $hash{$payby}->{shortname};
}

sub payname {
  my( $self, $payby ) = @_;
  #$hash{$payby}->{payname} || $hash{$payby}->{shortname};
  exists($hash{$payby}->{payname})
    ? $hash{$payby}->{payname}
    : $hash{$payby}->{shortname};
}

sub longname {
  my( $self, $payby ) = @_;
  $hash{$payby}->{longname};
}

%payby2bop = (
  'CARD' => 'CC',
  'CHEK' => 'ECHECK',
  'MCRD' => 'CC',
);

sub payby2bop {
  my( $self, $payby ) = @_;
  $payby2bop{ $self->payby2payment($payby) };
}

sub payby2payment {
  my( $self, $payby ) = @_;
  $hash{$payby}{'cust_pay'} || $payby;
}

sub cust_payby {
  my $self = shift;
  grep { ! exists $hash{$_}->{cust_main} } $self->payby;
}

sub cust_payby2longname {
  my $self = shift;
  map { $_ => $hash{$_}->{longname} } $self->cust_payby;
}

=back

=head1 BUGS

This should eventually be an actual database table, and all tables that
currently have a char payby field should have a foreign key into here instead.

=head1 SEE ALSO

=cut

1;

