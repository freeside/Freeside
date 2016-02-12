package FS::part_event::Condition::payby;
use base qw( FS::part_event::Condition );

use strict;

#this has no meaning in 4.x, but we need some sort of stub to upgrade

sub description {
  '(Deprecated) Customer payment type';
}

#never true, so never run?  that seems right.  this condition should have been
# migrated in your upgrade.  if not, not running is safter than running for all
# customers
sub condition { 0; }

sub disabled { 1; }

1;
