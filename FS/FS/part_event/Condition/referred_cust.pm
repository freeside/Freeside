package FS::part_event::Condition::referred_cust;
use base qw( FS::part_event::Condition );

sub description { 'Customer referred customers'; }

sub option_fields {
  (
    'number_referred' => { label => 'At least this many referred customers',
                           type  => 'text',
                           value => '1',
                         },
    'active'          => { label => 'Referred customers are active',
                           type  => 'checkbox',
                           value => 'Y',
                         },
    'if_pkg_class'    => { label    => 'Referred customers have an active package of class',
                           type     => 'select-pkg_class',
                           multiple => 1,
                         },
  );
}

sub condition {
  my($self, $object, %opt) = @_;

  my $cust_main = $self->cust_main($object);

  my @referral_cust_main = $cust_main->referral_cust_main;

  @referral_cust_main = grep $_->status eq 'active', @referral_cust_main
    if $self->option('active');

  my $if_pkg_class = $self->option('if_pkg_class') || {};
  if ( keys %$if_pkg_class ) {
    @referral_cust_main = grep {
      my $cust = $_;
      grep $if_pkg_class{$_->part_pkg->classnum}, $cust->active_pkgs;
    } @referral_cust_main;
  }

  scalar(@referral_cust_main) >= $self->option('number_referred');

}

#sub condition_sql {
#  my( $class, $table ) = @_;
#
#  #XXX TODO: this optimization
#}

1;
