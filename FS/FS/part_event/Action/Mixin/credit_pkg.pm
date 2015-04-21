package FS::part_event::Action::Mixin::credit_pkg;

use strict;

# credit_pkg: calculates a credit amount that is some percentage of the 
# package charge / cost / margin / some other amount of a package
#
# also provides an option field for the percentage, unless the action knows
# how to calculate its own percentage somehow (has a _calc_credit_percent)

sub eventtable_hashref {
  { 'cust_pkg' => 1 };
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
      'options' => [qw(
        base_recur_permonth cust_bill_pkg_recur recur_cost_permonth recur_margin_permonth
        unit_setup setup_cost setup_margin
      )],
      'labels'  => {
        'base_recur_permonth' => 'Base monthly fee',
        'cust_bill_pkg_recur' => 'Actual invoiced amount of most recent'.
                                 ' recurring charge',
        'recur_cost_permonth' => 'Monthly cost',
        'unit_setup'          => 'Setup fee',
        'setup_cost'          => 'Setup cost',
        'setup_margin'        => 'Setup margin (fee minus cost)',
        'recur_margin_permonth' => 'Monthly margin (fee minus cost)',
      },
    },
  );
  if ($class->can('_calc_credit_percent')) {
    splice @fields, 2, 2; #remove the percentage option
  }
  @fields;
}

# arguments:
# 1. cust_pkg
# 2. recipient of the credit (passed through to _calc_credit_percent)
# 3. optional scalar reference for recording a warning message

sub _calc_credit {
  my $self = shift;
  my $cust_pkg = shift;
  my $who = shift;
  my $warnref = shift;
  my $warning = '';

  my $cust_main = $self->cust_main($cust_pkg);

  my $part_pkg = $cust_pkg->part_pkg;

  my $what = $self->option('what');

  #false laziness w/Condition/cust_payments_pkg.pm
  if ( $what =~ /_permonth$/ ) { #huh.  yuck.
    if ( $part_pkg->freq !~ /^\d+$/ ) {
      die 'WARNING: Not crediting for package '. $cust_pkg->pkgnum.
          ' ( customer '. $cust_pkg->custnum. ')'.
          ' - credits not (yet) available for '.
          ' packages with '. $part_pkg->freq_pretty. ' frequency';
    }
  }

  my $percent;
  if ( $self->can('_calc_credit_percent') ) {
    $percent = $self->_calc_credit_percent($cust_pkg, $who) || 0;
    $warning = 'Percent calculated to zero ' unless $percent+0;
  } else {
    $percent = $self->option('percent') || 0;
    $warning = 'Percent set to zero ' unless $percent+0;
  }

  my @arg = ($what eq 'setup_cost') ? () : ($cust_pkg);
  my $charge = $part_pkg->$what(@arg) || 0;
  $warning .= "$what is zero" unless $charge+0;

  $$warnref .= $warning if ref($warnref);
  return sprintf('%.2f', $charge * $percent / 100 );
}

1;
