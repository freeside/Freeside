package FS::TicketSystem;

use strict;
use vars qw( $conf $system $AUTOLOAD );
use FS::Conf;
use FS::UID;

install_callback FS::UID sub { 
  $conf = new FS::Conf;
  $system = $conf->config('ticket_system');
};

sub AUTOLOAD {
  my $self = shift;

  my($sub)=$AUTOLOAD;
  $sub =~ s/.*://;

  my $conf = new FS::Conf;
  die "FS::TicketSystem::$AUTOLOAD called, but no ticket system configured\n"
    unless $system;

  eval "use FS::TicketSystem::$system;";
  die $@ if $@;

  $self .= "::$system";
  $self->$sub(@_);
}

1;
