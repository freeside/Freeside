package FS::part_export::sqlradius_withdomain;

use vars qw(@ISA);
use FS::part_export::sqlradius;

@ISA = qw(FS::part_export::sqlradius);

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->email;
}

