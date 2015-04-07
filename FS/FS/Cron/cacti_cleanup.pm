package FS::Cron::cacti_cleanup;
use base 'Exporter';
use vars '@EXPORT_OK';

use FS::Record qw( qsearch );
use Data::Dumper;

@EXPORT_OK = qw( cacti_cleanup );

sub cacti_cleanup {
  foreach my $export (qsearch({
    'table' => 'part_export',
    'hashref' => { 'exporttype' => 'cacti' }
  })) {
    $export->cleanup;
  }
}

1;
