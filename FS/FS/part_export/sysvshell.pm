package FS::part_export::sysvshell;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::passwdfile;

@ISA = qw(FS::part_export::passwdfile);

tie my %options, 'Tie::IxHash', %FS::part_export::passwdfile::options;

%info = (
  'svc'      => 'svc_acct',
  'desc'     =>
    'Batch export of /etc/passwd and /etc/shadow files (Linux, Solaris)',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes'    => <<'END'
MD5 crypt requires installation of
<a href="http://search.cpan.org/dist/Crypt-PasswdMD5">Crypt::PasswdMD5</a>
from CPAN.    Run bin/sysvshell.export to export the files.
END
);

1;

