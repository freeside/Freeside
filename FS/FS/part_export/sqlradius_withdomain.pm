package FS::part_export::sqlradius_withdomain;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::sqlradius;

tie my %options, 'Tie::IxHash', %FS::part_export::sqlradius::options;

$options{'strip_tld'} = { type  => 'checkbox',
                          label => 'Strip TLD from realm names',
                        };

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export to SQL-backed RADIUS (FreeRADIUS, ICRADIUS) with realms',
  'options'  => \%options,
  'nodomain' => '',
  'default_svc_class' => 'Internet',
  'notes' => $FS::part_export::sqlradius::notes1.
             'This export exports domains to RADIUS realms (see also '.
             'sqlradius).  '.
             $FS::part_export::sqlradius::notes2
);

@ISA = qw(FS::part_export::sqlradius);

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  my $email = $svc_acct->email;
  if ( $self->option('strip_tld') ) {
    $email =~ s/\.\w+$//;
  }
  $email;
}

1;

