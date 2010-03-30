package FS::part_event::Action::Mixin::credit_pkg;

use strict;

sub eventtable_hashref {
  { 'cust_pkg' => 1 };
}

sub option_fields {
  ( 
    'reasonnum' => { 'label'        => 'Credit reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'R',
                   },
    'percent'   => { 'label'   => 'Percent',
                     'type'    => 'input-percentage',
                     'default' => '100',
                   },
    'what' => { 'label'   => 'Of',
                'type'    => 'select',
                #add additional ways to specify in the package def
                'options' => [ qw( base_recur_permonth unit_setup recur_cost_permonth setup_cost ) ],
                'labels'  => { 'base_recur_permonth' => 'Base monthly fee',
                               'unit_setup'          => 'Setup fee',
                               'recur_cost_permonth' => 'Monthly cost',
                               'setup_cost'          => 'Setup cost',
                             },
              },
  );

}

#my %no_cust_pkg = ( 'setup_cost' => 1 );

sub _calc_credit {
  my( $self, $cust_pkg ) = @_;

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

  my $percent = $self->option('percent');

  #my @arg = $no_cust_pkg{$what} ? () : ($cust_pkg);
  my @arg = ($what eq 'setup_cost') ? () : ($cust_pkg);

  sprintf('%.2f', $part_pkg->$what(@arg) * $percent / 100 );

}

1;
