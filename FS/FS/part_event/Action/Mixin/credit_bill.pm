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
      'options' => [qw( setuprecur setup recur setuprecur_margin setup_margin recur_margin )],
      'labels'  => {
        'setuprecur'        => 'Amount charged',
        'setup'             => 'Setup fee',
        'recur'             => 'Recurring fee',
        'setuprecur_margin' => 'Amount charged minus total cost',
        'setup_margin'      => 'Setup fee minus setup cost',
        'recur_margin'      => 'Recurring fee minus recurring cost',
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

  my $what = $self->option('what');
  my $margin = 1 if $what =~ s/_margin$//;

  my $pkgnum = $cust_bill_pkg->pkgnum;
  my $cust_pkg = $cust_bill_pkg->cust_pkg;

  my $percent;
  if ( $self->can('_calc_credit_percent') ) {
    $percent = $self->_calc_credit_percent($cust_pkg, @_);
  } else {
    $percent = $self->option('percent') || 0;
  }

  my $charge = 0;
  if ( $what eq 'setup' ) {
    $charge = $cust_bill_pkg->get('setup');
  } elsif ( $what eq 'recur' ) {
    $charge = $cust_bill_pkg->get('recur');
  } elsif ( $what eq 'setuprecur' ) {
    $charge = $cust_bill_pkg->get('setup') + $cust_bill_pkg->get('recur');
  }
  if ( $margin ) {
    my $pkgpart = $cust_bill_pkg->pkgpart_override || $cust_pkg->pkgpart;
    my $part_pkg   = $part_pkg_cache{$pkgpart}
                 ||= FS::part_pkg->by_key($pkgpart);
    if ( $what eq 'setup' ) {
      $charge -= $part_pkg->get('setup_cost');
    } elsif ( $what eq 'recur' ) {
      $charge -= $part_pkg->get('recur_cost');
    } elsif ( $what eq 'setuprecur' ) {
      $charge -= $part_pkg->get('setup_cost') + $part_pkg->get('recur_cost');
    }
  }

  $charge = 0 if $charge < 0; # e.g. prorate
  return ($percent * $charge / 100);
}

1;
