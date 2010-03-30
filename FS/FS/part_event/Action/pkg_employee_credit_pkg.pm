package FS::part_event::Action::pkg_employee_credit_pkg;

use strict;
use base qw( FS::part_event::Action::Mixin::credit_pkg
             FS::part_event::Action::pkg_employee_credit );

sub description { 'Credit the ordering employee an amount based on the referred package'; }

1;
