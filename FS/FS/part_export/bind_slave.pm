package FS::part_export::bind_slave;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::null;

@ISA = qw(FS::part_export::null);

tie my %options, 'Tie::IxHash', 
  'master'       => { label=> 'Master IP address(s) (semicolon-separated)' },
  %FS::part_export::bind::options,
;
delete $options{'zonepath'};

%info = (
  'svc'     => 'svc_domain',
  'desc'    =>'Batch export to slave BIND named',
  'options' => \%options,
  'notes'   => <<'END'
Batch export of BIND configuration file to a secondary nameserver.  Zones are
slaved from the listed masters.
<a href="http://search.cpan.org/dist/File-Rsync">File::Rsync</a>
must be installed.  Run bin/bind.export to export the files.
END
);

1;

