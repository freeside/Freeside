package FS::part_event::Action::pkg_agent_credit_pkg_class;

use strict;
use base qw( FS::part_event::Action::Mixin::credit_pkg
             FS::part_event::Action::Mixin::credit_agent_pkg_class
             FS::part_event::Action::pkg_agent_credit );

sub description { 'Credit the agent an amount based on their commission percentage for the referred package class'; }

1;
