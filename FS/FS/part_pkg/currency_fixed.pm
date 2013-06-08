package FS::part_pkg::currency_fixed;
#can't discount yet
#use base qw( FS::part_pkg::discount_Mixin FS::part_pkg::recur_Common );
use base qw( FS::part_pkg::recur_Common );

use strict;
use vars qw( %info );
#use FS::Record qw(qsearch qsearchs);

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
                  )],
  'weight' => '59',
);

sub price_info {
    my $self = shift;
    my $str = $self->SUPER::price_info;
    $str .= " (or local currency pricing)" if $str;
    $str;
}

#some false laziness w/recur_Common, could have been better about it.. pry when
# we do discounting
sub calc_setup {
  my($self, $cust_pkg, $sdate, $details, $param) = @_;

  return 0 if $self->prorate_setup($cust_pkg, $sdate);

  sprintf('%.2f', $cust_pkg->part_pkg_currency_option('setup_fee') );
}

sub base_recur {
  my( $self, $cust_pkg ) = @_;
  sprintf('%.2f', $cust_pkg->part_pkg_currency_option('recur_fee') );
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
