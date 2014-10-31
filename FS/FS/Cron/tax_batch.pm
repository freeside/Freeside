package FS::Cron::tax_batch;

use FS::TaxEngine;
use FS::queue;
use base qw( Exporter );
@EXPORT_OK = 'process_tax_batch';

sub process_tax_batch {
  my %opt = @_;
  my $engine = FS::TaxEngine->new;
  return unless $engine->info->{batch};
  if ( $opt{'m'} ) {
    # then there may be queued_bill jobs running; wait for them to finish
    while(1) {
      my $num_jobs =
        FS::queue->count("job = 'FS::cust_main::queued_bill' AND ".
                         "status != 'failed'");
      last if $num_jobs == 0;
      warn "Waiting for billing jobs to finish ($num_jobs still active)...\n";
      sleep(30);
    }
  }
  $engine->transfer_batch(%opt);
}

1;
