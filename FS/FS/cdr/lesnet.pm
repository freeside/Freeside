package FS::cdr::lesnet;

use strict;
use vars qw( @ISA %info );

@ISA = qw(FS::cdr);

%info = (
  'name'          => 'LesNet',
  'weight'        => 120,
  'type'          => 'csv',
  'import_fields' => [
    # Call Date
    'calldate',

    # Source_Number
    'src',

    # Terminating_Number
    'dst',

    # Duration
    sub { my($cdr,$field) = @_;
            $cdr->duration($field);
            $cdr->billsec($field);
        },

    'upstream_price',
    
    'dcontext',

    'channel',
    
    # Sip Call id
    'dstchannel',

  ],
);

1;
