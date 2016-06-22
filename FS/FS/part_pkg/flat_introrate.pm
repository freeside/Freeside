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
  },
  'fieldorder' => [ qw(intro_duration intro_fee) ],
  'weight' => 14,
);

sub base_recur {
  my($self, $cust_pkg, $time ) = @_;

  warn "flat_introrate base_recur requires date!" if !$time;
  my $now = $time ? $$time : time;

  my ($duration) = ($self->option('intro_duration') =~ /^\s*(\d+)\s*$/);
  unless (length($duration)) {
    my $log = FS::Log->new('FS::part_pkg');
    $log->warning("Invalid intro_duration '".$self->option('intro_duration')."' on pkgpart ".$self->pkgpart
                .", defaulting to 0, check package definition");
    $duration = 0;
  }
  my $intro_end = $self->add_freq($cust_pkg->setup, $duration);

  if ($now < $intro_end) {
    return $self->option('intro_fee');
  } else {
    return $self->option('recur_fee');
  }

}


1;
