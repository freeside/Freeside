package FS::part_pkg::torrus_Common;

use base qw( FS::part_pkg::prorate );
use List::Util qw(max);

our %info = ( 'disabled' => 1 ); #recur_Common not a usable price plan directly

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += $self->calc_prorate(@_, 1);
  #$charges -= $self->calc_discount(@_);

  $charges;

}

#sub calc_cancel {  #somehow trigger an early report?

#have to look at getting the discounts to apply to the usage charges
sub can_discount { 0; }

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $serviceid = 'TESTING_1'; #XXX from svc_port (loop?)

  my $rep_id = 2; #XXX find the one matching the timeframe
  #SELECT id FROM WHERE reportname = 'MonthlyUsage' AND rep_date = ''

  #XXX abort if ! iscomplete?

  my $sql = "
    SELECT value FROM reportfields
      WHERE rep_id = $rep_id
        AND name = ?
        AND servciceid = ?
  ";
  
  my $in  = $self->scalar_sql($sql, $self->_torrus_name, $serviceid.'_IN');
  my $out = $self->scalar_sql($sql, $self->_torrus_name, $serviceid.'_OUT');

  my $max = max($in,$out);

  $max -= $self->option($self->_torrus_base);
  return 0 if $max < 0;

  #XXX add usage details

  return sprintf('%.2f', $self->option($self->_torrus_rate) * $max );

}


1;
