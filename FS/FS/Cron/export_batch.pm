package FS::Cron::export_batch;

use strict;
use vars qw( @ISA @EXPORT_OK $me $DEBUG );
use Exporter;
use FS::UID qw(dbh);
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::export_batch;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( export_batch_submit );
$DEBUG = 0;
$me = '[FS::Cron::export_batch]';

#freeside-daily %opt:
#  -v: enable debugging
#  -l: debugging level
#  -m: Experimental multi-process mode uses the job queue for multi-process and/or multi-machine billing.
#  -r: Multi-process mode dry run option
#  -a: Only process customers with the specified agentnum

sub export_batch_submit {
  my %opt = @_;
  local $DEBUG = ($opt{l} || 1) if $opt{v};
  
  warn "$me batch_submit\n" if $DEBUG;

  # like pay_batch, none of this is per-agent
  if ( $opt{a} ) {
    warn "Export batch processing skipped in per-agent mode.\n" if $DEBUG;
    return;
  }
  my @batches = qsearch({
      table     => 'export_batch',
      extra_sql => "WHERE status IN ('open', 'closed')",
  });

  foreach my $batch (@batches) {
    my $export = $batch->part_export;
    next if $export->disabled;
    warn "processing batchnum ".$batch->batchnum.
         " via ".$export->exporttype.  "\n"
      if $DEBUG;
    local $@;
    eval {
      $export->process($batch);
    };
    if ($@) {
      dbh->rollback;
      warn "export batch ".$batch->batchnum." failed: $@\n";
      $batch->set(status => 'failed');
      $batch->set(statustext => $@);
      my $error = $batch->replace;
      die "error recording batch status: $error"
        if $error;
      dbh->commit;
    }
  }
}

# currently there's no batch_receive() or anything of that sort

1;
