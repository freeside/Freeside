package Torrus::ReportOutput::Freeside;

use strict;
use warnings;
use base 'Torrus::Freeside';
use FS::UID qw(adminsuidsetup);
use FS::TicketSystem;

our $issetup = 0;

sub freesideSetup {
  #my $self = shift;

  return if $issetup++;

  adminsuidsetup('fs_queue'); #XXX for now
  FS::TicketSystem->init();

}

1;

