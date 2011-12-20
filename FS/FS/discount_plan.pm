package FS::discount_plan;

use strict;
use vars qw( $DEBUG $me );
use FS::Record qw( qsearch );
use FS::cust_bill;
use FS::cust_bill_pkg;
use FS::discount;
use List::Util qw( max );

=head1 NAME

FS::discount_plan - A term discount as applied to an invoice

=head1 DESCRIPTION

An FS::discount_plan object represents a term prepayment discount 
available for an invoice (L<FS::cust_bill>).  FS::discount_plan 
objects are non-persistent and do not inherit from FS::Record.

=head1 CLASS METHODS

=over 4

=item new OPTIONS

Calculate a discount plan.  OPTIONS must include:

cust_bill - the invoice to calculate discounts for

months - the number of months to be prepaid

If there are no line items on the invoice eligible for the discount
C<new()> will return undef.

=cut

sub new {
  my $class = shift;
  my %opt = @_;
  %opt = %{ $_[0] } if ( ref $_[0] );

  my $cust_bill = $opt{cust_bill}
    or die "$me new() requires 'cust_bill'\n";
  my $months = $opt{months}
    or die "$me new() requires 'months'\n";

  my ($previous_balance) = $cust_bill->previous;
  my $self = {
    cust_bill     => $cust_bill,
    months        => $months,
    pkgnums       => [],
    base          => $previous_balance || 0, # sum of charges before discount
    discounted    => $previous_balance || 0, # sum of charges after discount
    list_pkgnums  => undef, # whether any packages are not discounted
  };

  foreach my $cust_bill_pkg ( $cust_bill->cust_bill_pkg ) {
    my $cust_pkg = $cust_bill_pkg->cust_pkg or next;
    my $part_pkg = $cust_pkg->part_pkg or next;
    my $freq = $part_pkg->freq;
    my $setup = $cust_bill_pkg->setup || 0;
    my $recur = $cust_bill_pkg->recur || 0;

    if ( $freq eq '1' ) { # monthly recurring package
      my $permonth = $part_pkg->base_recur_permonth($cust_pkg) || 0;

      my ($discount) = grep { $_->months == $months }
      map { $_->discount } $part_pkg->part_pkg_discount;

      $self->{base} += $setup + $recur + ($months - 1) * $permonth;

      if ( $discount ) {

        my $discountable;
        if ( $discount->setup ) {
          $discountable += $setup;
        }
        else {
          $self->{discounted} += $setup;
        }

        if ( $discount->percent ) {
          $discountable += $months * $permonth;
          $discountable -= ($discountable * $discount->percent / 100);
          $discountable -= ($permonth - $recur); # correct for prorate
          $self->{discounted} += $discountable;
        }
        else {
          $discountable += $recur;
          $discountable -= $discount->amount * $recur/$permonth;
          $discountable += ($months - 1) * max($permonth - $discount->amount,0);
        }

        $self->{discounted} += $discountable;
        push @{ $self->{pkgnums} }, $cust_pkg->pkgnum;
      }
      else { #no discount
        $self->{discounted} += $setup + $recur + ($months - 1) * $permonth;
        $self->{list_pkgnums} = 1;
      }
    } #if $freq eq '1'
    else { # all non-monthly packages: include current charges only
      $self->{discounted} += $setup + $recur;
      $self->{base} += $setup + $recur;
      $self->{list_pkgnums} = 1;
    }
  } #foreach $cust_bill_pkg

  # we've considered all line items; exit if none of them are 
  # discountable
  return undef if $self->{base} == $self->{discounted} 
               or $self->{base} == 0;

  return bless $self, $class;

}

=item all CUST_BILL

For an L<FS::cust_bill> object, return a hash of all available 
discount plans, with discount term (months) as the key.

=cut

sub all {
  my $class = shift;
  my $cust_bill = shift;
  
  my %hash;
  foreach (qsearch('discount', { 'months' => { op => '>', value => 1 } })) {
    my $months = $_->months;
    my $discount_plan = $class->new(
      cust_bill => $cust_bill,
      months => $months
    );
    $hash{$_->months} = $discount_plan if defined($discount_plan);
  }

  %hash;
}

=back

=head1 METHODS

=over 4

=item discounted_total

Returns the total price for the term after applying discounts.  This is the 
price the customer would have to pay to receive the discount.  Note that 
this includes the monthly fees for all packages (including non-discountable
ones) for each month in the term, but only includes fees for other packages
as they appear on the current invoice.

=cut

sub discounted_total {
  my $self = shift;
  sprintf('%.2f', $self->{discounted});
}

=item base_total

Returns the total price for the term before applying discounts.

=cut

sub base_total {
  my $self = shift;
  sprintf('%.2f', $self->{base});
}

=item pkgnums

Returns a list of package numbers that are receiving discounts under this 
plan.

=cut

sub pkgnums {
  my $self = shift;
  @{ $self->{pkgnums} };
}

=item list_pkgnums

Returns a true value if any packages listed on the invoice do not 
receive a discount, either because there isn't one at the specified
term length or because they're not monthly recurring packages.

=cut

sub list_pkgnums {
  my $self = shift;
  $self->{list_pkgnums};
}

# any others?  don't think so

1;
