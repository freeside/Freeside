package FS::part_export::sqlradius_withdomain;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::sqlradius;

tie my %options, 'Tie::IxHash', %FS::part_export::sqlradius::options;

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export to SQL-backed RADIUS (FreeRADIUS, ICRADIUS, Radiator) with realms',
  'options'  => \%options,
  'nodomain' => '',
  'notes' => $FS::part_export::sqlradius::notes1.
             'This export exports domains to RADIUS realms (see also '.
             'sqlradius).  '.
             $FS::part_export::sqlradius::notes2
);

@ISA = qw(FS::part_export::sqlradius);

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->email;
}

1;

