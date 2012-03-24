package FS::part_pkg::discount_Mixin;

use strict;
use vars qw( %info );
use Time::Local qw( timelocal );
use List::Util  qw( min );
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

=item calc_discount

Takes all the arguments of calc_recur.  Calculates and returns  the amount 
by which to reduce the recurring fee; also increments months used on the 
discount and generates an invoice detail describing it.

=cut

sub calc_discount {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;
  my $conf = new FS::Conf;

  my $br = $self->base_recur_permonth($cust_pkg, $sdate);
  $br += $param->{'override_charges'} if $param->{'override_charges'};
 
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
    my $amount = 0;
    $amount += $discount->amount
        if $cust_pkg->pkgpart == $param->{'real_pkgpart'};
    $amount += sprintf('%.2f', $discount->percent * $br / 100 );
    my $chg_months = $param->{'months'} || $cust_pkg->part_pkg->freq;

    my $months = $discount->months
    ? min( $chg_months,
      $discount->months - $cust_pkg_discount->months_used )
    : $chg_months;

    if (defined $param->{'setup_charge'}) {
        next unless $discount->setup;

        if ( $discount->percent > 0 ) {
            $amount = sprintf('%.2f', $discount->percent * $param->{'setup_charge'} / 100 );
            $months = 1;
        } elsif ( $discount->amount > 0 && $discount->months == 1) {
            $discount_left = $param->{'setup_charge'} - $discount->amount;
            $amount = $param->{'setup_charge'} if $discount_left < 0;
            $amount = $discount->amount if $discount_left >= 0;
            $months = 1;
                
            # transfer remainder of discount, if any, to recur
            $param->{'discount_left_recur'}{$discount->discountnum} = 
                0 - $discount_left if $discount_left < 0;
        } else {
            next; 
        }
    } elsif ( defined $param->{'discount_left_recur'}{$discount->discountnum}
              && $param->{'discount_left_recur'}{$discount->discountnum} > 0
            ) {
        # use up transferred remainder of discount from setup
        $amount = $param->{'discount_left_recur'}{$discount->discountnum};
        $param->{'discount_left_recur'}{$discount->discountnum} = 0;
        $months = 1;
    } elsif (    $discount->setup
              && $discount->months == 1
              && $discount->amount > 0
            ) {
        next;
    }

    if ( ! defined $param->{'setup_charge'} ) {
      if ( $cust_pkg->pkgpart == $param->{'real_pkgpart'} ) {
        push @{ $param->{precommit_hooks} }, sub {
          my $error = $cust_pkg_discount->increment_months_used($months);
          die "error discounting: $error" if $error;
        };
      }

      $amount = min($amount, $br);
      $amount *= $months;
    }

    $amount = sprintf('%.2f', $amount + 0.00000001 ); #so 1.005 rounds to 1.01

    next unless $amount > 0;

    # transfer remainder of discount, if any, to setup
    if ( $discount->setup && $discount->amount > 0
        && (!$discount->months || $discount->months != 1)
        && !defined $param->{'setup_charge'}
       )
    {
      $discount_left = $br - $amount;
      if ( $discount_left < 0 ) {
        $amount = $br;
        $param->{'discount_left_setup'}{$discount->discountnum} = 
          0 - $discount_left;
      }
    }

    #record details in cust_bill_pkg_discount
    my $cust_bill_pkg_discount = new FS::cust_bill_pkg_discount {
      'pkgdiscountnum' => $cust_pkg_discount->pkgdiscountnum,
      'amount'         => $amount,
      'months'         => ( defined($param->{'setup_charge'}) ? 0 : $months ),
    };
    push @{ $param->{'discounts'} }, $cust_bill_pkg_discount;

    #add details on discount to invoice
    my $money_char = $conf->config('money_char') || '$';
    $months = sprintf('%.2f', $months) if $months =~ /\./;

    my $d = 'Includes ';
    $d .= 'setup ' if defined $param->{'setup_charge'};
    $d .= 'discount of '. $discount->description_short;
    $d .= " for $months month". ( $months!=1 ? 's' : '' ) unless defined $param->{'setup_charge'};
    $d .= ": $money_char$amount" if $months != 1 || $discount->percent;
    push @$details, $d;

    $tot_discount += $amount;
  }

  sprintf('%.2f', $tot_discount);
}

1;
