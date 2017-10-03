package FS::part_event::Condition::referred_cust_base_recur;
use base qw( FS::part_event::Condition );

use List::Util qw( sum );

sub description { 'Referred customers recurring per month'; }

sub option_fields {
  (
    'recur_times'  => { label => 'Base recurring per month of referred customers is at least this many times base recurring per month of referring customer',
                        type  => 'text',
                        value => '1',
                      },
    'if_pkg_class' => { label    => 'Only considering package of class',
                        type     => 'select-pkg_class',
                        multiple => 1,
                      },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);
  my @cust_pkg = $cust_main->billing_pkgs;

  my @referral_cust_main = $cust_main->referral_cust_main;
  my @referral_cust_pkg = map $_->billing_pkgs, @referral_cust_main;

  my $if_pkg_class = $self->option('if_pkg_class') || {};
  if ( keys %$if_pkg_class ) {
    @cust_pkg          = grep $_->part_pkg->classnum, @cust_pkg;
    @referral_cust_pkg = grep $_->part_pkg->classnum, @referral_cust_pkg;
  }

  return 0 unless @cust_pkg && @referral_cust_pkg;

  my $recur     = sum map $_->part_pkg->base_recur_permonth, @cust_pkg;
  my $ref_recur = sum map $_->part_pkg->base_recur_permonth, @referral_cust_pkg;

  $ref_recur >= $self->option('recur_times') * $recur;
}

#sub condition_sql {
#  my( $class, $table ) = @_;
#
#  #XXX TODO: this optimization
#}

1;

