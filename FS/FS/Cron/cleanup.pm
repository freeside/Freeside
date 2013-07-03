package FS::Cron::cleanup;
use base 'Exporter';
use vars '@EXPORT_OK';
use FS::queue;

@EXPORT_OK = qw( cleanup );

# start janitor jobs
sub cleanup {
# fix locations that are missing coordinates
  my $job = FS::queue->new({
      'job'     => 'FS::cust_location::process_set_coord',
      'status'  => 'new'
  });
  $job->insert('_JOB');
}

1;
