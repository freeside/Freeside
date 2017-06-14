package FS::part_pkg::fsinc_print;

use strict;
use vars qw( %info );
use FS::Record;

%info = (
  'name'      => 'Usage from Freeside Inc. web services',
  'shortname' => 'Freeside web services',
  'weight'    => '99',
);

sub price_info {
  my $self = shift;
  return 'printing usage';
}

sub base_setup { 0; }
sub calc_setup { 0; }

sub base_recur { 0; }
sub calc_recur {
  #my $self = shift;
  #my($self, $cust_pkg, $sdate, $details, $param ) = @_;
  my( $self, $cust_pkg ) = @_;

  my $custnum = $cust_pkg->custnum;

  #false laziness w/ClientAPI/Freeside.pm and webservice_log.pm
  my $color = 1.10;
  my $page = 0.10;

  FS::Record->scalar_sql("
    UPDATE webservice_log SET status = 'done'
      WHERE custnum = $custnum
        AND method = 'print'
        AND status IS NULL 
    RETURNING SUM ( $color + quantity * $page )
  ");

}

sub can_discount { 0; }

sub is_free { 0; }

1;
