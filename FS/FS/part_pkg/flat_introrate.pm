package FS::part_pkg::flat_introrate;
use base qw( FS::part_pkg::flat );

use strict;
use vars qw( %info );

use FS::Log;

# mostly false laziness with FS::part_pkg::global_Mixin::validate_moneyn,
# except for blank string handling...
sub validate_money {
  my ($option, $valref) = @_;
  if ( $$valref eq '' ) {
    $$valref = '0';
  } elsif ( $$valref =~ /^\s*(\d*)(\.\d{1})\s*$/ ) {
    #handle one decimal place without barfing out
    $$valref = ( ($1||''). ($2.'0') ) || 0;
  } elsif ( $$valref =~ /^\s*(\d*)(\.\d{2})?\s*$/ ) {
    $$valref = ( ($1||''). ($2||'') ) || 0;
  } else {
    return "Illegal (money) $option: ". $$valref;
  }
  return '';
}

sub validate_number {
  my ($option, $valref) = @_;
  $$valref = 0 unless $$valref;
  return "Invalid $option"
    unless ($$valref) = ($$valref =~ /^\s*(\d+)\s*$/);
  return '';
}

%info = (
  'name' => 'Introductory price for X months, then flat rate,'.
            'relative to setup date (anniversary billing)',
  'shortname' => 'Anniversary, with intro price',
  'inherit_fields' => [ 'flat', 'usage_Mixin', 'global_Mixin' ],
  'fields' => {
    'intro_fee' => { 'name' => 'Introductory recurring fee for this package',
                     'default' => 0,
                     'validate' => \&validate_money,
                   },
    'intro_duration' =>
         { 'name' => 'Duration of the introductory period, in number of months',
           'default' => 0,
           'validate' => \&validate_number,
         },
    'show_as_discount' =>
         { 'name' => 'Show the introductory rate on the invoice as if it\'s a discount',
           'type' => 'checkbox',
         },
  },
  'fieldorder' => [ qw(intro_duration intro_fee show_as_discount) ],
  'weight' => 14,
);

sub intro_end {
  my($self, $cust_pkg) = @_;
  my ($duration) = ($self->option('intro_duration') =~ /^\s*(\d+)\s*$/);
  unless (length($duration)) {
    my $log = FS::Log->new('FS::part_pkg');
    $log->warning("Invalid intro_duration '".$self->option('intro_duration')."' on pkgpart ".$self->pkgpart
                .", defaulting to 0, check package definition");
    $duration = 0;
  }

  # no setup or start_date means "start billing the package ASAP", so assume
  # it would start billing right now.
  my $start = $cust_pkg->setup || $cust_pkg->start_date || time;

  $self->add_freq($start, $duration);
}

sub base_recur {
  my($self, $cust_pkg, $time ) = @_;

  my $now;
  if (!$time) { # the "$sdate" from _make_lines
    my $log = FS::Log->new('FS::part_pkg');
    $log->warning("flat_introrate base_recur requires date!");
    $now = time;
  } else {
    $now = $$time;
  }

  if ($now < $self->intro_end($cust_pkg)) {
    return $self->option('intro_fee');
  } else {
    return $self->option('recur_fee');
  }

}

sub item_discount {
  my ($self, $cust_pkg) = @_;
  return unless $self->option('show_as_discount');
  my $intro_end = $self->intro_end($cust_pkg);
  my $amount = sprintf('%.2f',
                $self->option('intro_fee') - $self->option('recur_fee')
               );
  return unless $amount < 0;
  # otherwise it's an "introductory surcharge"? not the intended use of
  # the feature.

  { '_is_discount'    => 1,
    'description'     => $cust_pkg->mt('Introductory discount until') . ' ' .
                         $cust_pkg->time2str_local('short', $intro_end),
    'setup_amount'    => 0,
    'recur_amount'    => $amount,
    'ext_description' => [],
    'pkgpart'         => $self->pkgpart,
    'feepart'         => '',
  }
}

1;
