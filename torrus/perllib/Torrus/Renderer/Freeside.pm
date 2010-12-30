package Torrus::Renderer::Freeside;

use strict;
use warnings;
use base 'Torrus::Freeside';
use FS::UID qw(cgisuidsetup);
use FS::TicketSystem;

sub freesideSetup {
  #my $self = shift;

  cgisuidsetup($Torrus::CGI::q);
  FS::TicketSystem->init();

}

1;

