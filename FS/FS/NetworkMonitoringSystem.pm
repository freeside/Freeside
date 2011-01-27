package FS::NetworkMonitoringSystem;

use strict;
use vars qw( $conf $system $AUTOLOAD );
use FS::Conf;
use FS::UID;

FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $system = $conf->config('network_monitoring_system');
} );

sub AUTOLOAD {
  my $self = shift;

  my($sub)=$AUTOLOAD;
  $sub =~ s/.*://;

  my $conf = new FS::Conf;
  die "FS::NetworkMonitoringSystem::$AUTOLOAD called, but none configured\n"
    unless $system;

  eval "use FS::NetworkMonitoringSystem::$system;";
  die $@ if $@;

  $self .= "::$system";
  $self->$sub(@_);
}

1;
