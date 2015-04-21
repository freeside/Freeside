package FS::part_event::Action::pkg_referral_credit;

use strict;
use base qw( FS::part_event::Action::Mixin::credit_flat
             FS::part_event::Action  );

sub description { 'Credit the referring customer a specific amount'; }

sub eventtable_hashref {
  { 'cust_pkg' => 1 };
}

sub do_action {
  my( $self, $cust_pkg, $cust_event ) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

#  my $part_pkg = $cust_pkg->part_pkg;

  return 'No referring customer' unless $cust_main->referral_custnum;

  my $referring_cust_main = $cust_main->referring_cust_main;
  return 'Referring customer is cancelled'
    if $referring_cust_main->status eq 'cancelled';

  my $warning = '';
  my $amount    = $self->_calc_credit($cust_pkg, $referring_cust_main, \$warning);
  return $warning unless $amount > 0;

  my $reasonnum = $self->option('reasonnum');

  my $error = $referring_cust_main->credit(
    $amount, 
    \$reasonnum,
    'eventnum' => $cust_event->eventnum,
    'addlinfo' => 'for customer #'. $cust_main->display_custnum.
                               ': '.$cust_main->name,
  );
  die "Error crediting customer ". $cust_main->referral_custnum.
      " for referral: $error"
    if $error;

}

1;
