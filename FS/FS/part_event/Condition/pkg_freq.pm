package FS::part_event::Condition::pkg_freq;

use strict;
use FS::Misc;
use FS::cust_pkg;

use base qw( FS::part_event::Condition );

sub description { 'Package billing frequency'; }

sub option_fields {
  my $freqs = FS::Misc::pkg_freqs();
  (
    'freq' => { 'label'      => 'Frequency',
                'type'       => 'select',
                'labels'     => $freqs,
                'options'    => [ keys(%$freqs) ],
              },
  );
}

sub eventtable_hashref {
  { 'cust_main' => 0,
    'cust_bill' => 0,
    'cust_pkg'  => 1,
  };
}

sub condition {
  my($self, $cust_pkg) = @_;

  $cust_pkg->part_pkg->freq eq $self->option('freq')
}

1;

