package FS::part_event::Action::Mixin::credit_bill;

use strict;

# credit_bill: calculates a credit amount that is some percentage of each 
# line item of an invoice

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

sub option_fields {
  my $class = shift;
  my @fields = (
    'reasonnum' => { 'label'        => 'Credit reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'R',
                   },
    'percent'   => { 'label'   => 'Percent',
                     'type'    => 'input-percentage',
                     'default' => '100',
                   },
    'what' => {
      'label'   => 'Of',
      'type'    => 'select',
      #add additional ways to specify in the package def
      'options' => [qw( setuprecur setup recur setup_cost recur_cost setup_margin recur_margin_permonth )],
      'labels'  => {
        'setuprecur'        => 'Amount charged on this invoice',
        'setup'             => 'Setup fee charged on this invoice',
        'recur'             => 'Recurring fee charged on this invoice',
        'setup_cost'        => 'Setup cost',
        'recur_cost'        => 'Recurring cost',
        'setup_margin'      => 'Package setup fee minus setup cost',
        'recur_margin_permonth' => 'Monthly recurring fee minus recurring cost',
      },
    },
  );
  if ($class->can('_calc_credit_percent')) {
    splice @fields, 2, 2; #remove the percentage option
  }
  @fields;
    
}

our %part_pkg_cache;

# arguments:
# 1. the line item
# 2. the recipient of the commission; may be FS::sales, FS::agent, 
# FS::access_user, etc. Here we don't use it, but it will be passed through
# to _calc_credit_percent.

sub _calc_credit {
  my $self = shift;
  my $cust_bill_pkg = shift;
  my $who = shift;
  my $warnref = shift;
  my $warning = '';

  my $what = $self->option('what');
  my $cost = ($what =~ /_cost/ ? 1 : 0);
  my $margin = ($what =~ /_margin/ ? 1 : 0);

  my $pkgnum = $cust_bill_pkg->pkgnum;
  my $cust_pkg = $cust_bill_pkg->cust_pkg;

  my $percent;
  if ( $self->can('_calc_credit_percent') ) {
    $percent = $self->_calc_credit_percent($cust_pkg, $who);
    $warning = 'Percent calculated to zero ' unless $percent+0;
  } else {
    $percent = $self->option('percent') || 0;
    $warning = 'Percent set to zero ' unless $percent+0;
  }

  my $charge = 0;
  if ( $margin or $cost ) {
    # look up package costs only if we need them
    my $pkgpart = $cust_bill_pkg->pkgpart_override || $cust_pkg->pkgpart;
    my $part_pkg   = $part_pkg_cache{$pkgpart}
                 ||= FS::part_pkg->by_key($pkgpart);

    if ( $cost ) {
      $charge = $part_pkg->get($what);
    } else { # $margin
      $charge = $part_pkg->$what($cust_pkg);
    }

    $charge = ($charge || 0) * ($cust_pkg->quantity || 1);
    $warning .= 'Charge calculated to zero ' unless $charge+0;

  } else { # setup, recur, or setuprecur

    if ( $what eq 'setup' ) {
      $charge = $cust_bill_pkg->get('setup');
      $warning .= 'Setup is zero ' unless $charge+0;
    } elsif ( $what eq 'recur' ) {
      $charge = $cust_bill_pkg->get('recur');
      $warning .= 'Recur is zero ' unless $charge+0;
    } elsif ( $what eq 'setuprecur' ) {
      $charge = $cust_bill_pkg->get('setup') + $cust_bill_pkg->get('recur');
      $warning .= 'Setup and recur are zero ' unless $charge+0;
    }

    # don't multiply by quantity here; it's already included
  }

  $$warnref .= $warning if ref($warnref);

  $charge = 0 if $charge < 0; # e.g. prorate
  return ($percent * $charge / 100);
}

1;
