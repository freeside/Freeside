package FS::part_export::bind;

use vars qw(@ISA %info %options);
use Tie::IxHash;
use FS::part_export::null;

@ISA = qw(FS::part_export::null);

tie %options, 'Tie::IxHash',
  'named_conf'   => { label  => 'named.conf location',
                      default=> '/etc/bind/named.conf' },
  'zonepath'     => { label => 'path to zone files',
                      default=> '/etc/bind/', },
  'bind_release' => { label => 'ISC BIND Release',
                      type  => 'select',
                      options => [qw(BIND8 BIND9)],
                      default => 'BIND8' },
  'bind9_minttl' => { label => 'The minttl required by bind9 and RFC1035.',
                      default => '1D' },
  'reload'       => { label => 'Optional reload command.  If not specified, defaults to "ndc" under BIND8 and "rndc" under BIND9.', },
;                    

%info = (
  'svc'     => 'svc_domain',
  'desc'    => 'Batch export to BIND named',
  'options' => \%options,
  'notes'   => <<'END'
Batch export of BIND zone and configuration files to a primary nameserver.
<a href="http://search.cpan.org/search?dist=File-Rsync">File::Rsync</a>
must be installed.  Run bin/bind.export to export the files.
END
);

1;

