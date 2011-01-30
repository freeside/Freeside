package Torrus::Renderer::Freeside;

use strict;
use warnings;
use base 'Torrus::Freeside';
use FS::UID qw(cgisuidsetup);
use FS::TicketSystem;

our $cgi = '';

sub freesideSetup {
  #my $self = shift;

  return if $cgi eq $Torrus::CGI::q;

  $cgi = $Torrus::CGI::q;

  cgisuidsetup($cgi);
  FS::TicketSystem->init();

}

1;

