package FS::part_event::Action::pkg_referral_credit_pkg;

use strict;
use base qw( FS::part_event::Action::Mixin::credit_pkg
             FS::part_event::Action::pkg_referral_credit );

sub description { 'Credit the referring customer an amount based on the referred package'; }

1;
