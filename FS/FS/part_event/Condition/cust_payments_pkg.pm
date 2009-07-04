package FS::part_event::Condition::cust_payments_pkg;

use strict;
use base qw( FS::part_event::Condition );

sub description { 'Customer total payments (multiplier of package)'; }

sub eventtable_hashref {
  { 'cust_pkg' => 1 };
}

sub option_fields {
  (
    'over_times' => { 'label'      => 'Customer total payments as least',
                      'type'       => 'text',
                      'value'      => '1', #default
                    },
    'what' => { 'label'   => 'Times',
                'type'    => 'select',
                #also add some way to specify in the package def, no?
                'options' => [ qw( base_recur_permonth ) ],
                'labels'  => { 'base_recur_permonth' => 'Base monthly fee', },
              },
  );
}

sub condition {
  my($self, $cust_pkg) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

  my $part_pkg = $cust_pkg->part_pkg;

  my $over_times = $self->option('over_times');
  $over_times = 0 unless length($over_times);

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

  $cust_main->total_paid >= $over_times * $part_pkg->$what($cust_pkg);

}

#XXX add for efficiency.  could use cust_main::total_paid_sql
#use FS::cust_main;
#sub condition_sql {
#  my( $class, $table ) = @_;
#
#  my $over = $class->condition_sql_option('balance');
#
#  my $balance_sql = FS::cust_main->balance_sql;
#
#  "$balance_sql > $over";
#
#}

1;

