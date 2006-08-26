package FS::payby;

use strict;
use vars qw(%hash @EXPORT_OK);
use Tie::IxHash;


=head1 NAME

FS::payby - Object methods for payment type records

=head1 SYNOPSIS

  use FS::payby;

  #for now...

  my @payby = FS::payby->payby;

  tie my %payby, 'Tie::IxHash', FS::payby->payby2longname

  my @cust_payby = FS::payby->cust_payby;

  tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2longname

=head1 DESCRIPTION

Payment types.

=head1 METHODS

=over 4 

=item

=cut

tie %hash, 'Tie::IxHash',
  'CARD' => {
    tinyname  => 'card',
    shortname => 'Credit card',
    longname  => 'Credit card (automatic)',
  },
  'DCRD' => {
    tinyname  => 'card',
    shortname => 'Credit card',
    longname  => 'Credit card (on-demand)',
    cust_pay  => 'CARD', #this is a customer type only, payments are CARD...
  },
  'CHEK' => {
    tinyname  => 'check',
    shortname => 'Electronic check',
    longname  => 'Electronic check (automatic)',
  },
  'DCHK' => {
    tinyname  => 'check',
    shortname => 'Electronic check',
    longname  => 'Electronic check (on-demand)',
    cust_pay  => 'CHEK', #this is a customer type only, payments are CHEK...
  },
  'LECB' => {
    tinyname  => 'phone bill',
    shortname => 'Phone bill billing',
    longname  => 'Phone bill billing',
  },
  'BILL' => {
    tinyname  => 'billing',
    shortname => 'Billing',
    longname  => 'Billing',
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
  'COMP' => {
    tinyname  => 'comp',
    shortname => 'Complimentary',
    longname  => 'Complimentary',
  },
  'DCLN' => {  # This is only an event.
    tinyname  => 'declined',
    shortname => 'Declined payment',
    longname  => 'Declined payment',
  },
;

sub payby {
  keys %hash;
}

sub payby2longname {
  my $self = shift;
  map { $_ => $hash{$_}->{longname} } $self->payby;
}

sub payby2bop {
  { 'CARD' => 'CC'.
    'CHEK' => 'ECHECK',};
}

sub cust_payby {
  my $self = shift;
  grep { ! exists $hash{$_}->{cust_main} } $self->payby;
}

sub cust_payby2longname {
  my $self = shift;
  map { $_ => $hash{$_}->{longname} } $self->cust_payby;
}

sub payinfo_check{
  my($payby, $payinforef) = @_;

  if ($payby eq 'CARD') {
    $$payinforef =~ s/\D//g;
    if ($$payinforef){
      $$payinforef =~ /^(\d{13,16})$/
        or return "Illegal (mistyped?) credit card number (payinfo)";
      $$payinforef = $1;
      validate($$payinforef) or return "Illegal credit card number";
      return "Unknown card type" if cardype($$payinforef) eq "Unknown";
    } else {
      $$payinforef="N/A";
    }
  } else {
    $$payinforef =~ /^([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=]*)$/
    or return "Illegal text (payinfo)";
    $$payinforef = $1;
  }
}

=back

=head1 BUGS

This should eventually be an actual database table, and all tables that
currently have a char payby field should have a foreign key into here instead.

=head1 SEE ALSO

=cut

1;

