package FS::part_event::Action::pkg_sales_credit;

use strict;
use base qw( FS::part_event::Action::pkg_referral_credit );

sub description { 'Credit the sales person a specific amount'; }

#a little false laziness w/pkg_referral_credit
sub do_action {
  my( $self, $cust_pkg, $cust_event ) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

  my $sales = $cust_pkg->sales;
  $sales ||= $self->cust_main($cust_pkg)->sales
    if $self->option('cust_main_sales');

  return '' unless $sales; #no sales person, no credit

  die "No customer record for sales person ". $sales->salesperson
    unless $sales->sales_custnum;

  my $sales_cust_main = $sales->sales_cust_main;
    #? or return "No customer record for sales person ". $sales->salesperson;

  my $amount = $self->_calc_credit($cust_pkg);
  return '' unless $amount > 0;

  my $reasonnum = $self->option('reasonnum');

  my $error = $sales_cust_main->credit(
    $amount, 
    \$reasonnum,
    'eventnum'            => $cust_event->eventnum,
    'addlinfo'            => 'for customer #'. $cust_main->display_custnum.
                                          ': '.$cust_main->name.
                             ', package #'. $cust_pkg->pkgnum,
    'commission_salesnum' => $sales->salesnum,
    'commission_pkgnum'   => $cust_pkg->pkgnum,
  );
  die "Error crediting customer ". $sales_cust_main->custnum.
      " for sales commission: $error"
    if $error;

}

1;
