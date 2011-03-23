package FS::part_event::Condition::pkg_balance_under;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Package balance (under)'; }

sub option_fields {
  (
    'balance' => { 'label'      => 'Balance under (or equal to)',
                   'type'       => 'money',
                   'value'      => '0.00', #default
                 },
  );
}

sub eventtable_hashref {
  { 'cust_pkg' => 1, };
}

sub condition {
  my($self, $cust_pkg) = @_;

  my $cust_main = $self->cust_main($cust_pkg);

  my $under = $self->option('balance');
  $under = 0 unless length($under);

  $cust_main->balance_pkgnum($cust_pkg->pkgnum) <= $under;
}

1;

