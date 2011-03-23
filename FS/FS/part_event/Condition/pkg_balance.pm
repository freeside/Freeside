package FS::part_event::Condition::pkg_balance;

use strict;
use FS::cust_main;

use base qw( FS::part_event::Condition );

sub description { 'Package balance'; }


sub option_fields {
  (
    'balance' => { 'label'      => 'Balance over',
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

  my $over = $self->option('balance');
  $over = 0 unless length($over);

  $cust_main->balance_pkgnum($cust_pkg->pkgnum) > $over;
}

1;

