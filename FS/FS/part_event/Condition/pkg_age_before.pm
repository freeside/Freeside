package FS::part_event::Condition::pkg_age_before;
use base qw( FS::part_event::Condition::pkg_age_Common );

use strict;

sub description { 'Package Age Younger'; }

sub pkg_age_operator { '>'; }

sub pkg_age_label { 'Package date age younger than'; }

sub pkg_age_compare {
  my( $self, $pkg_date, $age ) = @_;

  $pkg_date > $age;
}

1;

