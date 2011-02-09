packages FS::Cron::nms_report;

use strict;
use base 'Exporter';
use FS::Conf;
use FS::NetworkMonitoringSystem;

our @EXPORT_OK = qw( nms_report );

sub nms_report {
  #my %opt = @_;

  my $conf = new FS::Conf;
  return unless $conf->config('network_monitoring_system');

  my $nms = new FS::NetworkMonitoringSystem;
  $nms->report; #(%opt);

}

1;
