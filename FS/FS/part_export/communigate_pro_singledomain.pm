package FS::part_export::communigate_pro_singledomain;

use vars qw(@ISA);
use FS::part_export::communigate_pro;

@ISA = qw(FS::part_export::communigate_pro);

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->username. '@'. $self->option('domain');
}
