package FS::Cron::lnp_vitelity;
use base qw( Exporter );

use vars qw( @EXPORT_OK );
use FS::Record qw( qsearch );
use FS::part_export;

@EXPORT_OK = qw( lnp_vitelity );

sub lnp_vitelity {
  $_->check_lnp foreach qsearch('part_export', {exporttype=>'vitelity'} );
}

1;
