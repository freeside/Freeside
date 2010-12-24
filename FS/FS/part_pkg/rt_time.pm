package FS::part_pkg::rt_time;

use strict;
use FS::Conf;
use FS::Record qw(qsearchs qsearch);
use FS::part_pkg::recur_Common;
use Carp qw(cluck);

our @ISA = qw(FS::part_pkg::recur_Common);

our $DEBUG = 0;

our %info = (
  'name'      =>  'Bill from Time Worked on tickets in RT',
  'shortname' =>  'Project Billing (RT)',
  'weight'    => 55,
  'inherit_fields' => [ 'global_Mixin' ],
  'fields'    =>  {
    'base_rate' =>  {   'name'    =>  'Rate (per minute)',
                        'default' => 0,
                    },
    'recur_fee' => {'disabled' => 1},
  },
  'fieldorder' => [ 'base_rate' ],
);

sub calc_setup {
  my($self, $cust_pkg ) = @_;
  $self->option('setup_fee');
}

sub calc_recur {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $charges = 0;

  $charges += $self->calc_usage(@_);
  $charges += $self->calc_recur_Common(@_);

  $charges;

}

sub can_discount { 0; }

sub calc_cancel {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  $self->calc_usage(@_);
}

sub calc_usage {
  my $self = shift;
  my($cust_pkg, $sdate, $details, $param ) = @_;

  my $last_bill = $cust_pkg->get('last_bill') || $cust_pkg->get('setup');
  my @tickets = @{ FS::TicketSystem->comments_on_tickets( $cust_pkg->custnum, 100, $last_bill ) };

  my $charges = 0;

  my $rate = $self->option('base_rate');

  foreach my $ding ( @tickets) {
        $charges += sprintf('%.2f', $ding->{'timetaken'} * $rate);
        push @$details, join( ", ", ("($ding->{timetaken}) Minutes", substr($ding->{'content'},0,255)));
  }
  cluck $rate, $charges, @$details if $DEBUG > 0;
  return $charges;
}

1;
