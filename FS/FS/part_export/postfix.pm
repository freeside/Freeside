package FS::part_export::postfix;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export::null;

@ISA = qw(FS::part_export::null);

tie my %options, 'Tie::IxHash',
  'user'    => { label=>'Remote username',       default=>'root' },
  'aliases' => { label=>'aliases file location', default=>'/etc/aliases' },
  'virtual' => { label=>'virtual file location', default=>'/etc/postfix/virtual' },
  'mydomain' => { label=>'local domain', default=>'' },
  'newaliases' => { label=>'newaliases command', default=>'newaliases' },
  'postmap'    => { label=>'postmap command',
                    default=>'postmap hash:/etc/postfix/virtual', },
  'reload'     => { label=>'reload command',
                    default=>'postfix reload' },
;

%info = (
  'svc'     => 'svc_forward',
  'desc'    => 'Postfix text files',
  'options' => \%options,
  'default_svc_class' => 'Email',
  'notes'   => <<'END'
Batch export of Postfix aliases and virtual files.
<a href="http://search.cpan.org/dist/File-Rsync">File::Rsync</a>
must be installed.  Run bin/postfix.export to export the files.
END
);

1;
