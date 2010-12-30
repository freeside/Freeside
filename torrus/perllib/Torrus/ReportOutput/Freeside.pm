package Torrus::ReportOutput::Freeside;

use strict;
use warnings;
use base 'Torrus::Freeside';
use FS::UID qw(adminsuidsetup);
use FS::TicketSystem;

sub freesideSetup {
  #my $self = shift;

  adminsuidsetup('fs_queue'); #XXX for now
  FS::TicketSystem->init();

}

1;

