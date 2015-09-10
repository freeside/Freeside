package Torrus::Renderer::Freeside;

use strict;
use warnings;
use base 'Torrus::Freeside';
use FS::UID qw(setcgi adminsuidsetup);
use FS::TicketSystem;

our $cgi = '';

sub freesideSetup {
  #my $self = shift;

  return if $cgi eq $Torrus::CGI::q;

  $cgi = $Torrus::CGI::q;

  setcgi($cgi);

  adminsuidsetup;
  FS::TicketSystem->init();

}

1;

