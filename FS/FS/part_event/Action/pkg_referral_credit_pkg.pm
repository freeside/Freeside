package FS::part_event::Action::pkg_referral_credit_pkg;

use strict;
use base qw( FS::part_event::Action::pkg_referral_credit );

sub description { 'Credit the referring customer an amount based on the referred package'; }

#sub eventtable_hashref {
#  { 'cust_pkg' => 1 };
#}

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
                #also add some way to specify in the package def, no?
                'options' => [ qw( base_recur_permonth ) ],
                'labels'  => { 'base_recur_permonth' => 'Base monthly fee', },
              },
  );

}

sub _calc_referral_credit {
  my( $self, $cust_pkg ) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

  my $part_pkg = $cust_pkg->part_pkg;

  my $what = $self->option('what');

  #false laziness w/Condition/cust_payments_pkg.pm
  if ( $what eq 'base_recur_permonth' ) { #huh.  yuck.
    if ( $part_pkg->freq !~ /^\d+$/ ) {
      die 'WARNING: Not crediting customer '. $cust_main->referral_custnum.
          ' for package '. $cust_pkg->pkgnum.
          ' ( customer '. $cust_pkg->custnum. ')'.
          ' - Referral credits not (yet) available for '.
          ' packages with '. $part_pkg->freq_pretty. ' frequency';
    }
  }

  my $percent = $self->option('percent');

  sprintf('%.2f', $part_pkg->$what($cust_pkg) * $percent / 100 );

}

1;
