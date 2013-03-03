package FS::part_event::Action::referral_pkg_discount;

use strict;
use base qw( FS::part_event::Action );

sub description { "Discount the referring customer's package"; }

#sub eventtable_hashref {
#}

sub option_fields {
  (
    'if_pkgpart'  => { 'label'    => 'Only packages',
                       'type'     => 'select-part_pkg',
                       'multiple' => 1,
                     },
    'discountnum' => { 'label'    => 'Discount',
                       'type'     => 'select-table', #we don't handle the select-discount create a discount case
                       'table'    => 'discount',
                       'name_col' => 'description', #well, method
                       'order_by' => 'ORDER BY discountnum', #requied because name_col is a method
                       'hashref'  => { 'disabled' => '',
                                       'months'   => { op=>'!=', value=>'0' },
                                     },
                       'disable_empty' => 1,
                     },
  );
}

#false laziness w/referral_pkg_billdate, probably should make
# Mixin/referral_pkg.pm if we need changes or anything else in this vein
sub do_action {
  my( $self, $cust_object, $cust_event ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  return 'No referring customer' unless $cust_main->referral_custnum;

  my $referring_cust_main = $cust_main->referring_cust_main;
  #return 'Referring customer is cancelled'
  #  if $referring_cust_main->status eq 'cancelled';

  my %if_pkgpart = map { $_=>1 } split(/\s*,\s*/, $self->option('if_pkgpart') );
  my @cust_pkg = grep $if_pkgpart{ $_->pkgpart },
                      $referring_cust_main->billing_pkgs;
  return 'No qualifying billing package definition' unless @cust_pkg;

  my $cust_pkg = $cust_pkg[0]; #only one

  #end of false laziness

  my @cust_pkg_discount = $cust_pkg->cust_pkg_discount_active;
  my @my_cust_pkg_discount =
    grep { $_->discountnum == $self->option('discountnum') } @cust_pkg_discount;

  if ( @my_cust_pkg_discount ) { #increment the existing one instead

    die "guru meditation #and: multiple discounts"
      if scalar(@my_cust_pkg_discount) > 1;
 
    my $cust_pkg_discount = $my_cust_pkg_discount[0];
    my $discount = $cust_pkg_discount->discount;
    die "guru meditation #goob: can't extended non-expiring discount"
      if $discount->months == 0;

    my $error = $cust_pkg_discount->decrement_months_used( $discount->months );
    die "Error extending discount: $error\n" if $error;

  } elsif ( @cust_pkg_discount ) {

    #"stacked" discount case not possible from UI, not handled, so prevent
    # against creating one here.  i guess we could try to find a different
    # @cust_pkg above if this case needed to be handled better?
    die "Can't discount an already discounted package";

  } else { #normal case, create a new one

    my $cust_pkg_discount = new FS::cust_pkg_discount {
      'pkgnum'      => $cust_pkg->pkgnum,
      'discountnum' => $self->option('discountnum'),
      'months_used' => 0,
      #'end_date'    => '',
      #we dont handle the create a new discount case
      #'_type'       => scalar($cgi->param('discountnum__type')),
      #'amount'      => scalar($cgi->param('discountnum_amount')),
      #'percent'     => scalar($cgi->param('discountnum_percent')),
      #'months'      => scalar($cgi->param('discountnum_months')),
      #'setup'       => scalar($cgi->param('discountnum_setup')),
      ##'linked'       => scalar($cgi->param('discountnum_linked')),
      ##'disabled'    => $self->discountnum_disabled,
    };
    my $error = $cust_pkg_discount->insert;
    die "Error discounting package: $error\n" if $error;

  }

  '';

}

1;
