package FS::part_pkg::discount_Mixin;

use strict;
use vars qw( %info );
use Time::Local qw( timelocal );
use List::Util  qw( min );
use FS::Record qw( qsearchs );
use FS::cust_pkg;
use FS::cust_bill_pkg_discount;

%info = ( 'disabled' => 1 );

=head1 NAME

FS::part_pkg::discount_Mixin - Mixin class for part_pkg:: classes that 
can be discounted.

=head1 SYNOPSIS

package FS::part_pkg::...;
use base qw( FS::part_pkg::discount_Mixin );

sub calc_recur {
  ...
  my $discount = $self->calc_discount($cust_pkg, $$sdate, $details, $param);
  $charge -= $discount;
  ...
}

=head METHODS

=item calc_discount CUST_PKG, SDATE, DETAILS_ARRAYREF, PARAM_HASHREF

Takes all the arguments of calc_recur.  Calculates and returns the amount 
by which to reduce the charge; also increments months used on the discount.

If there is a setup fee, this will be called once with 'setup_charge' => the
setup fee amount (and should return the discount to be applied to the setup
charge, if any), and again without it (for the recurring fee discount). 
PARAM_HASHREF carries over between the two invocations.

=cut

sub calc_discount {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;
  my $conf = new FS::Conf;

  my $br = $self->base_recur($cust_pkg, $sdate);
  $br += $param->{'override_charges'} * ($cust_pkg->part_pkg->freq || 0) if $param->{'override_charges'};

  my $tot_discount = 0;
  #UI enforces just 1 for now, will need ordering when they can be stacked

  if ( $param->{freq_override} ) {
    # When a customer pays for more than one month at a time to receive a 
    # term discount, freq_override is set to the number of months.
    my $real_part_pkg = new FS::part_pkg { $self->hash };
    $real_part_pkg->pkgpart($param->{real_pkgpart} || $self->pkgpart);
    # Find a discount with that duration...
    my @discount = grep { $_->months == $param->{freq_override} }
                    map { $_->discount } $real_part_pkg->part_pkg_discount;
    my $discount = shift @discount;
    # and default to bill that many months at once.
    $param->{months} = $param->{freq_override} unless $param->{months};
    my $error;
    if ($discount) {
      # Then set the cust_pkg discount.
      if ($discount->months == $param->{months}) {
        $cust_pkg->discountnum($discount->discountnum);
        $error = $cust_pkg->insert_discount;
      } else {
        $cust_pkg->discountnum(-1);
        foreach ( qw( amount percent months ) ) {
          my $method = "discountnum_$_";
          $cust_pkg->$method($discount->$_);
        }
        $error = $cust_pkg->insert_discount;
      }
      die "error discounting using part_pkg_discount: $error" if $error;
    }
  }

  my @cust_pkg_discount = $cust_pkg->cust_pkg_discount_active;
  foreach my $cust_pkg_discount ( @cust_pkg_discount ) {
    my $discount_left;
    my $discount = $cust_pkg_discount->discount;
    #UI enforces one or the other (for now?  probably for good)
    # $chg_months: the number of months we are charging recur for
    # $months: $chg_months or the months left on the discount, whchever is less

    my $chg_months = $cust_pkg->part_pkg->freq || 1;
    if ( defined($param->{'months'}) ) { # then override
      $chg_months = $param->{'months'};
    }

    my $months = $chg_months;
    if ( $discount->months ) {
      $months = min( $chg_months,
                     $discount->months - $cust_pkg_discount->months_used );
    }

    # $amount is now the (estimated) discount amount on the recurring charge.
    # if it's a percent discount, that's base recur * percentage.

    my $amount = 0;

    if (defined $param->{'setup_charge'}) {

        # we are calculating the setup discount.
        # if this discount doesn't apply to setup fees, skip it.
        # if it's a percent discount, set $amount = percent * setup_charge.
        # if it's a flat amount discount for one month:
        # - if the discount amount > setup_charge, then set it to setup_charge,
        #   and set 'discount_left_recur' to the difference.
        # - otherwise set it to just the discount amount.
        # if it's a flat amount discount for other than one month:
        # - skip the discount. unsure, leaving it alone for now.

        next unless $discount->setup;

        $months = 0; # never count a setup discount as a month of discount
                     # (the recur discount in the same month should do it)

        if ( $discount->percent > 0 ) {
            $amount = $discount->percent * $param->{'setup_charge'} / 100;
        } elsif ( $discount->amount > 0 && ($discount->months || 0) == 1) {
            # apply the discount amount, up to a maximum of the setup charge
            $amount = min($discount->amount, $param->{'setup_charge'});
            $discount_left = sprintf('%.2f', $discount->amount - $amount);
            # transfer remainder of discount, if any, to recur
            $param->{'discount_left_recur'}{$discount->discountnum} = $discount_left;
        } else {
          # I guess we don't allow multiple-month flat amount discounts to
          # apply to setup?
            next; 
        }

    } else {
      
      # we are calculating a recurring fee discount. estimate the recurring
      # fee:
      # XXX it would be more accurate for calc_recur to just _tell us_ what
      # it's going to charge

      my $recur_charge = $br * $chg_months / $self->freq;
      # round this, because the real recur charge is rounded
      $recur_charge = sprintf('%.2f', $recur_charge);

      # if it's a percentage discount, calculate it based on that estimate.
      # otherwise use the flat amount.
      
      if ( $discount->percent > 0 ) {
        $amount = $recur_charge * $discount->percent / 100;
      } elsif ( $discount->amount > 0
                and $cust_pkg->pkgpart == $param->{'real_pkgpart'} ) {
        $amount = $discount->amount * $months;
      }

      if ( exists $param->{'discount_left_recur'}{$discount->discountnum} ) {
        # there is a discount_left_recur entry for this discountnum, so this
        # is the second (recur) pass on the discount.  use up transferred
        # remainder of discount from setup.
        #
        # note that discount_left_recur can now be zero.
        $amount = $param->{'discount_left_recur'}{$discount->discountnum};
        $param->{'discount_left_recur'}{$discount->discountnum} = 0;
        $months = 1; # XXX really? not $chg_months?
      }
      #elsif (    $discount->setup
      #          && ($discount->months || 0) == 1
      #          && $discount->amount > 0
      #        ) {
      #    next;
      #
      #    RT #11512: bugfix to prevent applying flat discount to both setup
      #    and recur. The original implementation ignored discount_left_recur
      #    if it was zero, so if the setup fee used up the entire flat 
      #    discount, the recurring charge would get to use the entire flat
      #    discount also. This bugfix was a kludge. Instead, we now allow
      #    discount_left_recur to be zero in that case, and then the available
      #    recur discount is zero. 
      #}

      # transfer remainder of discount, if any, to setup
      # this is used when the recur phase wants to add a setup fee
      # (prorate_defer_bill): the "discount_left_setup" amount will
      # be subtracted in _make_lines.
      if ( $discount->setup && $discount->amount > 0
          && ($discount->months || 0) != 1
         )
      {
        # $amount is no longer permonth at this point! correct. very good.
        $discount_left = $amount - $recur_charge; # backward, as above
        if ( $discount_left > 0 ) {
          $amount = $recur_charge;
          $param->{'discount_left_setup'}{$discount->discountnum} = 
            0 - $discount_left;
        }
      }

      # cap the discount amount at the recur charge
      $amount = min($amount, $recur_charge);

      # if this is the base pkgpart, schedule increment_months_used to run at
      # the end of billing. (addon packages haven't been calculated yet, so
      # don't let the discount expire during the billing process. RT#17045.)
      if ( $cust_pkg->pkgpart == $param->{'real_pkgpart'} ) {
        push @{ $param->{precommit_hooks} }, sub {
          my $error = $cust_pkg_discount->increment_months_used($months);
          die "error discounting: $error" if $error;
        };
      }

    }

    $amount = sprintf('%.2f', $amount + 0.00000001 ); #so 1.005 rounds to 1.01

    next unless $amount > 0;

    #record details in cust_bill_pkg_discount
    my $cust_bill_pkg_discount = new FS::cust_bill_pkg_discount {
      'pkgdiscountnum' => $cust_pkg_discount->pkgdiscountnum,
      'amount'         => $amount,
      'months'         => $months,
      # XXX should have a 'setuprecur'
    };
    push @{ $param->{'discounts'} }, $cust_bill_pkg_discount;
    $tot_discount += $amount;

  }

  sprintf('%.2f', $tot_discount);
}

1;
