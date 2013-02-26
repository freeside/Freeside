package FS::part_event::Action::referral_pkg_billdate;

use strict;
use base qw( FS::part_event::Action );

sub description { "Increment the referring customer's package's next bill date"; }

#sub eventtable_hashref {
#}

sub option_fields {
  (
    'if_pkgpart' => { 'label'    => 'Only packages',
                      'type'     => 'select-part_pkg',
                      'multiple' => 1,
                    },
    'increment'  => { 'label'    => 'Increment by',
                      'type'     => 'freq',
                      'value'    => '1m',
                    },
  );
}

sub do_action {
  my( $self, $cust_object, $cust_event ) = @_;

  my $cust_main = $self->cust_main($cust_object);

  return 'No referring customer' unless $cust_main->referral_custnum;

  my $referring_cust_main = $cust_main->referring_cust_main;
  #return 'Referring customer is cancelled'
  #  if $referring_cust_main->status eq 'cancelled';

  my %if_pkgpart = map { $_=>1 } split(/\s*,\s*/, $self->option('if_pkgpart') );
  my @cust_pkg = grep $if_pkgpart{ $_->pkgpart },
                      $referring_cust_main->billing_pkgs;
  return 'No qualifying billing package definition' unless @cust_pkg;

  my $cust_pkg = $cust_pkg[0]; #only one

  my $bill = $cust_pkg->bill || $cust_pkg->setup || time;

  $cust_pkg->bill(
    $cust_pkg->part_pkg->add_freq( $bill, $self->option('increment') )
  );

  my $error = $cust_pkg->replace;
  die "Error incrementing next bill date: $error" if $error;

  '';

}

1;
