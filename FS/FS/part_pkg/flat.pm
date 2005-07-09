package FS::part_pkg::flat;

use strict;
use vars qw(@ISA %info);
#use FS::Record qw(qsearch);
use FS::part_pkg;
use Date::Manip;

@ISA = qw(FS::part_pkg);

%info = (
  'name' => 'Flat rate (anniversary billing)',
  'fields' => {
    'setup_fee'     => { 'name' => 'Setup fee for this package',
                         'default' => 0,
                       },
    'recur_fee'     => { 'name' => 'Recurring fee for this package',
                         'default' => 0,
                       },
    'unused_credit' => { 'name' => 'Credit the customer for the unused portion'.
                                   ' of service at cancellation',
                         'type' => 'checkbox',
                       },
  },
  'fieldorder' => [ 'setup_fee', 'recur_fee', 'unused_credit' ],
  #'setup' => 'what.setup_fee.value',
  #'recur' => 'what.recur_fee.value',
  'weight' => 10,
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my $self = shift;
  $self->base_recur(@_);
}

sub base_recur {
  my($self, $cust_pkg) = @_;
  $self->option('recur_fee');
}

sub calc_remain {
  my ($self, $cust_pkg) = @_;
  my $time = time;
  my $next_bill = $cust_pkg->getfield('bill') || 0;
  my $last_bill = $cust_pkg->last_bill || 0;
  return 0 if    ! $self->base_recur
              || ! $self->option('unused_credit', 1)
              || ! $last_bill
              || ! $next_bill;

  my $now_date = ParseDate("epoch $time");
  my $last_date = ParseDate("epoch $last_bill");
  my $next_date = ParseDate("epoch $next_bill");
  my $err;
  my $delta = DateCalc($now_date,$next_date,\$err, 0);
  my $days_remaining = Delta_Format($delta, 4, "%dh");

  my $frequency = $self->freq;

  # TODO: Remove this after the frequencies are Data::Manip friendly.
  $frequency .= "m" unless $frequency =~ /[wd]$/;

  my $freq_delta = ParseDateDelta($frequency);
  my $days = Delta_Format($freq_delta,4,"%dh");

  my $recurring= $self->base_recur;
  my $daily =  $recurring/$days;

  sprintf("%.2f",($daily * $days_remaining));
}

sub is_free_options {
  qw( setup_fee recur_fee );
}

sub is_prepaid {
  0; #no, we're postpaid
}

1;
