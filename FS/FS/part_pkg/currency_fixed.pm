package FS::part_pkg::currency_fixed;
#can't discount yet
#use base qw( FS::part_pkg::discount_Mixin FS::part_pkg::recur_Common );
use base qw( FS::part_pkg::recur_Common );

use strict;
use vars qw( %info );
use FS::Record qw(qsearchs); # qsearch qsearchs);
use FS::currency_exchange;

%info = (
  'name' => 'Per-currency pricing from package definitions',
  'shortname' => 'Per-currency pricing',
  'inherit_fields' => [ 'prorate_Mixin', 'global_Mixin' ],
  'fields' => {
    'cutoff_day'    => { 'name' => 'Billing Day (1 - 28) for prorating or '.
                                   'subscription',
                         'default' => '1',
                       },

    'recur_method'  => { 'name' => 'Recurring fee method',
                         #'type' => 'radio',
                         #'options' => \%recur_method,
                         'type' => 'select',
                         'select_options' => \%FS::part_pkg::recur_Common::recur_method,
                       },
  },
  'fieldorder' => [qw( recur_method cutoff_day ),
                   FS::part_pkg::prorate_Mixin::fieldorder,
                  ],
  'weight' => '59',
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= " (or local currency pricing)" if $str;
    $str;
}

sub base_setup {
  my($self, $cust_pkg, $sdate, $details, $param ) = @_;

  $self->calc_currency_option('setup_fee', $cust_pkg, $sdate, $details, $param);
}

sub calc_setup {
  my($self, $cust_pkg, $sdate, $details, $param) = @_;

  return 0 if $self->prorate_setup($cust_pkg, $sdate);

  $self->base_setup($cust_pkg, $sdate, $details, $param);
}

use FS::Conf;
sub calc_currency_option {
  my($self, $optionname, $cust_pkg, $sdate, $details, $param) = @_;

  my($currency, $amount) = $cust_pkg->part_pkg_currency_option($optionname);
  return sprintf('%.2f', $amount ) unless $currency;

  $param->{'billed_currency'} = $currency;
  $param->{'billed_amount'}   = $amount;

  my $currency_exchange = qsearchs('currency_exchange', {
    'from_currency' => $currency,
    'to_currency'   => ( FS::Conf->new->config('currency') || 'USD' ),
  }) or die "No exchange rate from $currency\n";

  #XXX do we want the rounding here to work differently?
  #my $recognized_amount =
  sprintf('%.2f', $amount * $currency_exchange->rate);
}

sub base_recur {
  my( $self, $cust_pkg, $sdate, $details, $param ) = @_;
  $param ||= {};
  $self->calc_currency_option('recur_fee', $cust_pkg, $sdate, $details, $param);
}

sub can_discount { 0; } #can't discount yet (percentage would work, but amount?)
sub calc_recur {
  my $self = shift;
  #my($cust_pkg, $sdate, $details, $param ) = @_;
  #$self->calc_recur_Common($cust_pkg,$sdate,$details,$param);
  $self->calc_recur_Common(@_);
}

sub is_free { 0; }

sub can_currency_exchange { 1; }

1;
