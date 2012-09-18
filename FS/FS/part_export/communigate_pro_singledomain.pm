package FS::part_export::communigate_pro_singledomain;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::communigate_pro;

@ISA = qw(FS::part_export::communigate_pro);

tie my %options, 'Tie::IxHash', %FS::part_export::communigate_pro::options,
  'domain'   => { label=>'Domain', },
;

%info = (
  'svc'      => 'svc_acct',
  'desc'     =>
    'Real-time export to a CommuniGate Pro mail server, one domain only',
  'options'  => \%options,
  'nodomain' => 'Y',
  'default_svc_class' => 'Email',
  'notes'    => <<'END'
Real time export to a
<a href="http://www.stalker.com/CommuniGatePro/">CommuniGate Pro</a>
mail server.  This is an unusual export to CommuniGate Pro that forces all
accounts into a single domain.  As CommuniGate Pro supports multiple domains,
unless you have a specific reason for using this export, you probably want to
use the communigate_pro export instead.  The
<a href="http://www.stalker.com/CGPerl/">CommuniGate Pro Perl Interface</a>
must be installed as CGP::CLI.
END
);

sub export_username {
  my($self, $svc_acct) = (shift, shift);
  $svc_acct->username. '@'. $self->option('domain');
}

1;

