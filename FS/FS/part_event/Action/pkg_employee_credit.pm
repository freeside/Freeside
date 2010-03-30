package FS::part_event::Action::pkg_employee_credit;

use strict;
use base qw( FS::part_event::Action::pkg_referral_credit );

sub description { 'Credit the ordering employee a specific amount'; }

#a little false laziness w/pkg_referral_credit
sub do_action {
  my( $self, $cust_pkg, $cust_event ) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

  my $employee = $cust_pkg->access_user;
  return "No customer record for employee ". $employee->username
    unless $employee->user_custnum;

  my $employee_cust_main = $employee->user_cust_main;
    #? or return "No customer record for employee ". $employee->username;

  my $amount    = $self->_calc_credit($cust_pkg);
  return '' unless $amount > 0;

  my $reasonnum = $self->option('reasonnum');

  my $error = $employee_cust_main->credit(
    $amount, 
    \$reasonnum,
    'eventnum' => $cust_event->eventnum,
    'addlinfo' => 'for customer #'. $cust_main->display_custnum.
                               ': '.$cust_main->name,
  );
  die "Error crediting customer ". $employee_cust_main->custnum.
      " for employee commission: $error"
    if $error;

}

1;
