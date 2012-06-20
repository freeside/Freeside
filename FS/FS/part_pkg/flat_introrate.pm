package FS::part_pkg::flat_introrate;

use strict;
use vars qw(@ISA %info $DEBUG $me);
use FS::part_pkg::flat;

@ISA = qw(FS::part_pkg::flat);
$me = '[' . __PACKAGE__ . ']';
$DEBUG = 0;

%info = (
  'name' => 'Introductory price for X months, then flat rate,'.
            'relative to setup date (anniversary billing)',
  'shortname' => 'Anniversary, with intro price',
  'inherit_fields' => [ 'flat', 'usage_Mixin', 'global_Mixin' ],
  'fields' => {
    'intro_fee' => { 'name' => 'Introductory recurring fee for this package',
                     'default' => 0,
                   },
    'intro_duration' =>
         { 'name' => 'Duration of the introductory period, in number of months',
           'default' => 0,
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
    die "Invalid intro_duration: " . $self->option('intro_duration');
  }
  my $intro_end = $self->add_freq($cust_pkg->setup, $duration);

  if ($now < $intro_end) {
    return $self->option('intro_fee');
  } else {
    return $self->option('recur_fee');
  }

}


1;
