package FS::part_export::passwdfile;

use strict;
use vars qw(@ISA %options);
use Tie::IxHash;
use FS::part_export::null;

@ISA = qw(FS::part_export::null);

tie %options, 'Tie::IxHash',
  'crypt' => { label=>'Password encryption',
               type=>'select', options=>[qw(crypt md5)],
               default=>'crypt',
             },
;

1;

