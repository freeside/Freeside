package FS::part_event::Action::pkg_referral_credit;

use strict;
use base qw( FS::part_event::Action );

sub description { 'Credit the referring customer a specific amount'; }

sub eventtable_hashref {
  { 'cust_pkg' => 1 };
}

sub option_fields {
  ( 
    'reasonnum' => { 'label'        => 'Credit reason',
                     'type'         => 'select-reason',
                     'reason_class' => 'R',
                   },
    'amount'    => { 'label'        => 'Credit amount',
                     'type'         => 'money',
                   },
  );

}

sub do_action {
  my( $self, $cust_pkg ) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

#  my $part_pkg = $cust_pkg->part_pkg;

  return 'No referring customer' unless $cust_main->referral_custnum;

  my $referring_cust_main = $cust_main->referring_cust_main;
  return 'Referring customer is cancelled'
    if $referring_cust_main->status eq 'cancelled';

  my $amount    = $self->_calc_credit($cust_pkg);
  return '' unless $amount > 0;

  my $reasonnum = $self->option('reasonnum');

  my $error = $referring_cust_main->credit(
    $amount, 
    \$reasonnum,
    'addlinfo' =>
      'for customer #'. $cust_main->display_custnum. ': '.$cust_main->name,
  );
  die "Error crediting customer ". $cust_main->referral_custnum.
      " for referral: $error"
    if $error;

}

sub _calc_credit {
  my( $self, $cust_pkg ) = @_;

  $self->option('amount');
}

1;
