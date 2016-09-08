package FS::Cron::send_subscribed;

use strict;
use base 'Exporter';
use FS::saved_search;
use FS::Record qw(qsearch);
use FS::queue;

our @EXPORT_OK = qw( send_subscribed );
our $DEBUG = 1;

sub send_subscribed {

  my @subs = qsearch('saved_search', {
    'disabled'  => '',
    'freq'      => { op => '!=', value => '' },
  });
  foreach my $saved_search (@subs) {
    my $date = $saved_search->next_send_date;
    warn "checking '".$saved_search->searchname."' with date $date\n"
      if $DEBUG;
    
    if ( $^T > $saved_search->next_send_date ) {
      warn "queueing delivery\n";
      my $job = FS::queue->new({ job => 'FS::saved_search::queueable_send' });
      $job->insert( $saved_search->searchnum );
    }
  }

}

1;
